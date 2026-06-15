#ifndef C_ONNX_RUNTIME_SHIM_H
#define C_ONNX_RUNTIME_SHIM_H

typedef struct HifzORTSession HifzORTSession;

typedef struct HifzORTLogProbabilities {
    float *values;
    int time_step_count;
    int vocabulary_size;
    int value_count;
} HifzORTLogProbabilities;

const char *HifzORTVersionString(void);
int HifzORTCreateSession(const char *model_path, HifzORTSession **out_session, char **out_error);
void HifzORTDestroySession(HifzORTSession *session);
int HifzORTSessionInputCount(HifzORTSession *session, int *out_count, char **out_error);
int HifzORTSessionOutputCount(HifzORTSession *session, int *out_count, char **out_error);
int HifzORTSessionInputName(HifzORTSession *session, int index, char **out_name, char **out_error);
int HifzORTSessionOutputName(HifzORTSession *session, int index, char **out_name, char **out_error);
int HifzORTRunLogProbabilities(
    HifzORTSession *session,
    const float *features,
    int feature_count,
    int frame_count,
    HifzORTLogProbabilities *out_log_probabilities,
    char **out_error
);
void HifzORTFreeString(char *value);
void HifzORTFreeFloatBuffer(float *value);

#endif
