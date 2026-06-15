#include "COnnxRuntimeShim.h"

#include <onnxruntime_c_api.h>
#include <stdlib.h>
#include <string.h>

struct HifzORTSession {
    OrtEnv *env;
    OrtSessionOptions *options;
    OrtSession *session;
    OrtAllocator *allocator;
};

static const OrtApi *HifzORTApi(void) {
    return OrtGetApiBase()->GetApi(ORT_API_VERSION);
}

static void HifzORTSetError(char **out_error, const char *message) {
    if (out_error == NULL) {
        return;
    }
    *out_error = strdup(message != NULL ? message : "Unknown ONNX Runtime error.");
}

static int HifzORTFailStatus(const OrtApi *api, OrtStatus *status, char **out_error) {
    if (status == NULL) {
        return 0;
    }
    HifzORTSetError(out_error, api->GetErrorMessage(status));
    api->ReleaseStatus(status);
    return -1;
}

static int HifzORTCopyAllocatedName(
    const OrtApi *api,
    OrtAllocator *allocator,
    char *allocated_name,
    char **out_name,
    char **out_error
) {
    if (allocated_name == NULL) {
        HifzORTSetError(out_error, "ONNX Runtime returned an empty metadata name.");
        return -1;
    }

    *out_name = strdup(allocated_name);
    OrtStatus *free_status = api->AllocatorFree(allocator, allocated_name);
    if (free_status != NULL) {
        api->ReleaseStatus(free_status);
    }

    if (*out_name == NULL) {
        HifzORTSetError(out_error, "Unable to copy ONNX Runtime metadata name.");
        return -1;
    }

    return 0;
}

const char *HifzORTVersionString(void) {
    return OrtGetApiBase()->GetVersionString();
}

int HifzORTCreateSession(const char *model_path, HifzORTSession **out_session, char **out_error) {
    const OrtApi *api = HifzORTApi();
    HifzORTSession *wrapper = calloc(1, sizeof(HifzORTSession));
    if (wrapper == NULL) {
        HifzORTSetError(out_error, "Unable to allocate ONNX Runtime session wrapper.");
        return -1;
    }

    if (HifzORTFailStatus(api, api->CreateEnv(ORT_LOGGING_LEVEL_WARNING, "HifzTracker", &wrapper->env), out_error) != 0) {
        HifzORTDestroySession(wrapper);
        return -1;
    }

    if (HifzORTFailStatus(api, api->CreateSessionOptions(&wrapper->options), out_error) != 0) {
        HifzORTDestroySession(wrapper);
        return -1;
    }

    if (HifzORTFailStatus(api, api->SetIntraOpNumThreads(wrapper->options, 2), out_error) != 0) {
        HifzORTDestroySession(wrapper);
        return -1;
    }

    if (HifzORTFailStatus(api, api->SetSessionGraphOptimizationLevel(wrapper->options, ORT_ENABLE_ALL), out_error) != 0) {
        HifzORTDestroySession(wrapper);
        return -1;
    }

    if (HifzORTFailStatus(api, api->CreateSession(wrapper->env, model_path, wrapper->options, &wrapper->session), out_error) != 0) {
        HifzORTDestroySession(wrapper);
        return -1;
    }

    if (HifzORTFailStatus(api, api->GetAllocatorWithDefaultOptions(&wrapper->allocator), out_error) != 0) {
        HifzORTDestroySession(wrapper);
        return -1;
    }

    *out_session = wrapper;
    return 0;
}

void HifzORTDestroySession(HifzORTSession *session) {
    if (session == NULL) {
        return;
    }

    const OrtApi *api = HifzORTApi();
    if (session->session != NULL) {
        api->ReleaseSession(session->session);
    }
    if (session->options != NULL) {
        api->ReleaseSessionOptions(session->options);
    }
    if (session->env != NULL) {
        api->ReleaseEnv(session->env);
    }
    free(session);
}

static void HifzORTReleaseValue(const OrtApi *api, OrtValue **value) {
    if (*value != NULL) {
        api->ReleaseValue(*value);
        *value = NULL;
    }
}

static int HifzORTValidateRunInputs(
    const float *features,
    int feature_count,
    int frame_count,
    HifzORTLogProbabilities *out_log_probabilities,
    char **out_error
) {
    if (features == NULL) {
        HifzORTSetError(out_error, "Feature buffer is empty.");
        return -1;
    }
    if (feature_count <= 0 || frame_count <= 0) {
        HifzORTSetError(out_error, "Feature and frame counts must be positive.");
        return -1;
    }
    if (out_log_probabilities == NULL) {
        HifzORTSetError(out_error, "Output log probability buffer is missing.");
        return -1;
    }
    return 0;
}

int HifzORTRunLogProbabilities(
    HifzORTSession *session,
    const float *features,
    int feature_count,
    int frame_count,
    HifzORTLogProbabilities *out_log_probabilities,
    char **out_error
) {
    if (HifzORTValidateRunInputs(features, feature_count, frame_count, out_log_probabilities, out_error) != 0) {
        return -1;
    }

    memset(out_log_probabilities, 0, sizeof(HifzORTLogProbabilities));

    const OrtApi *api = HifzORTApi();
    OrtMemoryInfo *memory_info = NULL;
    OrtValue *input_values[2] = { NULL, NULL };
    OrtValue *output_values[1] = { NULL };
    OrtTensorTypeAndShapeInfo *shape_info = NULL;
    float *copied_values = NULL;

    int64_t feature_shape[3] = { 1, (int64_t)feature_count, (int64_t)frame_count };
    size_t feature_byte_count = (size_t)feature_count * (size_t)frame_count * sizeof(float);
    int64_t length_shape[1] = { 1 };
    int64_t length_value[1] = { (int64_t)frame_count };

    if (HifzORTFailStatus(api, api->CreateCpuMemoryInfo(OrtArenaAllocator, OrtMemTypeDefault, &memory_info), out_error) != 0) {
        goto fail;
    }

    if (HifzORTFailStatus(
        api,
        api->CreateTensorWithDataAsOrtValue(
            memory_info,
            (void *)features,
            feature_byte_count,
            feature_shape,
            3,
            ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT,
            &input_values[0]
        ),
        out_error
    ) != 0) {
        goto fail;
    }

    if (HifzORTFailStatus(
        api,
        api->CreateTensorWithDataAsOrtValue(
            memory_info,
            (void *)length_value,
            sizeof(length_value),
            length_shape,
            1,
            ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64,
            &input_values[1]
        ),
        out_error
    ) != 0) {
        goto fail;
    }

    const char *input_names[2] = { "audio_signal", "length" };
    const char *output_names[1] = { "logprobs" };

    if (HifzORTFailStatus(
        api,
        api->Run(session->session, NULL, input_names, (const OrtValue *const *)input_values, 2, output_names, 1, output_values),
        out_error
    ) != 0) {
        goto fail;
    }

    if (HifzORTFailStatus(api, api->GetTensorTypeAndShape(output_values[0], &shape_info), out_error) != 0) {
        goto fail;
    }

    size_t dimension_count = 0;
    if (HifzORTFailStatus(api, api->GetDimensionsCount(shape_info, &dimension_count), out_error) != 0) {
        goto fail;
    }

    if (dimension_count != 2 && dimension_count != 3) {
        HifzORTSetError(out_error, "Expected ONNX logprobs shape [T,V] or [1,T,V].");
        goto fail;
    }

    int64_t dimensions[3] = { 0, 0, 0 };
    if (HifzORTFailStatus(api, api->GetDimensions(shape_info, dimensions, dimension_count), out_error) != 0) {
        goto fail;
    }

    int64_t time_steps = dimension_count == 3 ? dimensions[1] : dimensions[0];
    int64_t vocabulary_size = dimension_count == 3 ? dimensions[2] : dimensions[1];
    if (time_steps <= 0 || vocabulary_size <= 0) {
        HifzORTSetError(out_error, "ONNX logprobs returned an empty shape.");
        goto fail;
    }

    size_t element_count = 0;
    if (HifzORTFailStatus(api, api->GetTensorShapeElementCount(shape_info, &element_count), out_error) != 0) {
        goto fail;
    }

    void *raw_output = NULL;
    if (HifzORTFailStatus(api, api->GetTensorMutableData(output_values[0], &raw_output), out_error) != 0) {
        goto fail;
    }

    copied_values = malloc(element_count * sizeof(float));
    if (copied_values == NULL) {
        HifzORTSetError(out_error, "Unable to allocate log probability output buffer.");
        goto fail;
    }
    memcpy(copied_values, raw_output, element_count * sizeof(float));

    out_log_probabilities->values = copied_values;
    out_log_probabilities->time_step_count = (int)time_steps;
    out_log_probabilities->vocabulary_size = (int)vocabulary_size;
    out_log_probabilities->value_count = (int)element_count;

    if (shape_info != NULL) {
        api->ReleaseTensorTypeAndShapeInfo(shape_info);
    }
    HifzORTReleaseValue(api, &output_values[0]);
    HifzORTReleaseValue(api, &input_values[1]);
    HifzORTReleaseValue(api, &input_values[0]);
    if (memory_info != NULL) {
        api->ReleaseMemoryInfo(memory_info);
    }
    return 0;

fail:
    free(copied_values);
    if (shape_info != NULL) {
        api->ReleaseTensorTypeAndShapeInfo(shape_info);
    }
    HifzORTReleaseValue(api, &output_values[0]);
    HifzORTReleaseValue(api, &input_values[1]);
    HifzORTReleaseValue(api, &input_values[0]);
    if (memory_info != NULL) {
        api->ReleaseMemoryInfo(memory_info);
    }
    return -1;
}

int HifzORTSessionInputCount(HifzORTSession *session, int *out_count, char **out_error) {
    const OrtApi *api = HifzORTApi();
    size_t count = 0;
    if (HifzORTFailStatus(api, api->SessionGetInputCount(session->session, &count), out_error) != 0) {
        return -1;
    }
    *out_count = (int)count;
    return 0;
}

int HifzORTSessionOutputCount(HifzORTSession *session, int *out_count, char **out_error) {
    const OrtApi *api = HifzORTApi();
    size_t count = 0;
    if (HifzORTFailStatus(api, api->SessionGetOutputCount(session->session, &count), out_error) != 0) {
        return -1;
    }
    *out_count = (int)count;
    return 0;
}

int HifzORTSessionInputName(HifzORTSession *session, int index, char **out_name, char **out_error) {
    const OrtApi *api = HifzORTApi();
    char *allocated_name = NULL;
    if (HifzORTFailStatus(
        api,
        api->SessionGetInputName(session->session, (size_t)index, session->allocator, &allocated_name),
        out_error
    ) != 0) {
        return -1;
    }
    return HifzORTCopyAllocatedName(api, session->allocator, allocated_name, out_name, out_error);
}

int HifzORTSessionOutputName(HifzORTSession *session, int index, char **out_name, char **out_error) {
    const OrtApi *api = HifzORTApi();
    char *allocated_name = NULL;
    if (HifzORTFailStatus(
        api,
        api->SessionGetOutputName(session->session, (size_t)index, session->allocator, &allocated_name),
        out_error
    ) != 0) {
        return -1;
    }
    return HifzORTCopyAllocatedName(api, session->allocator, allocated_name, out_name, out_error);
}

void HifzORTFreeString(char *value) {
    free(value);
}

void HifzORTFreeFloatBuffer(float *value) {
    free(value);
}
