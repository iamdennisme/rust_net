#include <stdint.h>
#include <stdlib.h>

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

FFI_PLUGIN_EXPORT uint64_t rust_net_client_create(const char *config_json);
FFI_PLUGIN_EXPORT char *rust_net_client_execute(uint64_t client_id, const char *request_json);
FFI_PLUGIN_EXPORT void rust_net_client_close(uint64_t client_id);
FFI_PLUGIN_EXPORT void rust_net_string_free(char *value);
