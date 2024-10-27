#ifndef JOURNEY_AUDIO_LIBRARY_H
#define JOURNEY_AUDIO_LIBRARY_H

/*
 * Assumption:
 * All cpus using this library support the following intrinsics;
 * SSE, SSE2, SSE3, SSSE3, SSE4.1, SSE4.2, AVX, AVX2, FMA3 (Skylake : Zen)
 *
 * All Audio file passed through are 48000 or 441000 not higher nor lower.
 * Channel count is either 1 or 2
 * The Audio format is WAVE_FORMAT_PCM (integer) or WAVE_FORMAT_IEEE_FLOAT (floating)
 * The common precision of the audio format is 16 (integer) and 32 (floating point)
 *
 * integer I16, float 32
 *
 * */


/*
 *
 * Thoughts:
 *
 * Most Allocation will be handled on odin lang, but if the function take in an allocation then it will do allocation on the data returned.
 * Should we add wasapi low latency mode? What is it used for? The advantages and dis-advantages.
 * */

/*
 * references:
 * https://support.focusrite.com/hc/en-gb/articles/115004120965-Sample-Rate-Bit-Depth-Buffer-Size-Explained
 * https://www.hresult.info/FACILITY_AUDCLNT
 *
 * */

#include <mmdeviceapi.h>
#include <audioclient.h>
#include <devicetopology.h>
#include <endpointvolume.h>

#include <immintrin.h>
#include <emmintrin.h>

#include <stdio.h> //TODO: remove me to and remove printf calls

#define JA_LFORCE_INLINE static __forceinline
#define JA_LINLINE static __inline

#define JA_COINIT_DEFAULT 0x0000000C /* COINIT_MULTITHREADED |  COINIT_DISABLE_OLE1DDE | COINIT_SPEED_OVER_MEMORY */
#define JA_SUCCESS 0


typedef unsigned long long QWORD;

//BOOL32 = TRUE if it is 0 otherwise it is false (can't be negative)
//specified bits in BOOL32 will report the specific error type in the library.
typedef DWORD BOOL32;
typedef float FLOAT32;
typedef double FLOAT64;

//The IAudioClient object is not initialized.
#define JA_AUDIOCLNT_NOT_INITIALIZED ((HRESULT)0x88890001)

//The IAudioClient object is already initialized.
#define JA_AUDIOCLNT_ALREADY_INITIALIZED ((HRESULT)0x88890002)

//The AUDCLNT_STREAMFLAGS_LOOPBACK flag is set but the endpoint device is a capture device, not a rendering device.
#define JA_AUDIOCLNT_WRONG_ENDPOINT_TYPE ((HRESULT)0x88890003)

//The audio endpoint device has been unplugged, or the audio hardware or associated hardware resource has been reconfigured, disabled, removed or otherwise made unavailable for use.
#define JA_AUDIOCLNT_DEVICE_INVALIDATED ((HRESULT)0x88890004)

//The audio stream was not stopped at the time of the start call.
#define JA_AUDIOCLNT_NOT_STOPPED ((HRESULT)0x88890005)

//The NumFrameRequested value exceeds the available buffer space (buffer size - padding size)
#define JA_AUDIOCLNT_BUFFER_TO_LARGE ((HRESULT)0x88890006)

//The previous IAudioRenderClient::GetBuffer procedure call is still in effect.
#define JA_AUDIOCLNT_OUT_OF_ORDER ((HRESULT)0x88890007)

//
#define JA_AUDIOCLNT_UNSUPPORTED_FORMAT ((HRESULT)
///////////////////////////////////////////WIN32/////////////////////////////////////////////////////////

#define JA_DONT_RESOLVE_DLL_REFERENCES 0x00000001
#define JA_LOAD_IGNORE_CODE_AUTHZ_LEVEL 0x00000010
#define JA_LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR 0x00000100
#define JA_LOAD_LIBRARY_SEARCH_DEFAULT_DIRS 0x00001000
#define JA_LOAD_LIBRARY_AS_DATAFILE 0x00000002
#define JA_LOAD_LIBRARY_AS_IMAGE_RESOURCE 0x00000020
#define JA_LOAD_LIBRARY_SEARCH_APPLICATION_DIR 0x00000200
#define JA_LOAD_LIBRARY_SAFE_CURRENT_DIRS 0x00002000
#define JA_LOAD_LIBRARY_AS_DATAFILE_EXCLUSIVE 0x00000040
#define JA_LOAD_LIBRARY_SEARCH_USER_DIRS 0x00000400
#define JA_LOAD_WITH_ALTERED_SEARCH_PATH 0x00000008
#define JA_LOAD_LIBRARY_REQUIRE_SIGNED_TARGET 0x00000080
#define JA_LOAD_LIBRARY_SEARCH_SYSTEM32 0x00000800

//procedure pointers
typedef HRESULT (WINAPI * JA_CoInitializeEx)(void* pvReserved, DWORD dwCoInit);
typedef HRESULT (WINAPI * JA_CoCreateInstance)(const IID* ref_clsid, void* unknown_outer, DWORD cls_context, IID* iid, void* ppv);
//A thread must call CoUninitialize once for each successful call it has made to the CoInitialize or CoInitializeEx function, including any call that returns S_FALSE.
typedef void (WINAPI * JA_CoUninitialize)();
typedef void* (WINAPI * JA_CoTaskMemAlloc)(QWORD byte_size);
typedef void (WINAPI * JA_CoTaskMemFree)(void* mem_block);
typedef void* (WINAPI * JA_CoTaskMemRealloc)(void* mem_block, QWORD byte_size);
typedef HRESULT (WINAPI * JA_FreePropVariantArray)(DWORD count, PROPVARIANT * prop_variants);
typedef HRESULT (WINAPI * JA_PropVariantClear)(PROPVARIANT * prop_variant);
typedef HRESULT (WINAPI * JA_PropVariantCopy)(PROPVARIANT * dst_prop_variant, const PROPVARIANT * src_prop_variant);

JA_LINLINE BOOL32 JAFileOpen(FILE** file, const char* path, const char* open_mode){
    errno_t err = fopen_s(file, path, open_mode);

    if (err != JA_SUCCESS){
        //Convert the error to JAError
    }

    return 0;
}

JA_LINLINE BOOL32 JAWFileOpen(FILE** file, const wchar_t* path, const wchar_t* open_mode){

    errno_t err = _wfopen_s(file, path, open_mode);

    if (err != JA_SUCCESS){
        //Convert the error to JAError
    }

    return JA_SUCCESS;
}

//////////////////////////////////////////Allocator///////////////////////////////////////////////////////

//Allocate, Free, ReAlloc, Copy


///////////////////////////////////////////DECODE////////////////////////////////////////////////////////






///////////////////////////////////////////WASAPI////////////////////////////////////////////////////////

#define JAPrimarySampleRate 48000
#define JASecondarySampleRate 44100

#define MinChannel 1
#define MaxChannel 2

/*
 *
 * Audio format type:
 * S16
 *
 */

static const PROPERTYKEY JA_PKEY_Device_FriendlyName = {{0xA45C254E, 0xDF1C, 0x4EFD, {0x80, 0x20, 0x67, 0xD1, 0x46, 0xA8, 0x50, 0xE0}}, 0x0E};

static const PROPERTYKEY JA_PKEY_AudioEngine_DeviceFormat = {{0xf19f064d,0x82c,0x4e27,0xbc, 0x73, 0x68, 0x82, 0xa1, 0xbb, 0x8e, 0x4c}, 0x0};
static const PROPERTYKEY JA_PKEY_AudioEngine_OEMFormat = {{0xe4870e26, 0x3cc5, 0x4cd2, 0xba, 0x46, 0xca, 0xa, 0x9a, 0x70, 0xed, 0x4}, 0x03};

static const PROPERTYKEY JA_PKEY_AudioEndpoint_FormFactor = {{0x1da5d803, 0xd492, 0x4edd, 0x8c, 0x23, 0xe0, 0xc0, 0xff, 0xee, 0x7f, 0x0e}, 0x00};
static const PROPERTYKEY JA_PKEY_AudioEndpoint_ControlPanelPageProvider = {{0x1da5d803, 0xd492, 0x4edd, 0x8c, 0x23, 0xe0, 0xc0, 0xff, 0xee, 0x7f, 0x0e}, 0x01};
static const PROPERTYKEY JA_PKEY_AudioEndpoint_Association = {{0x1da5d803, 0xd492, 0x4edd, 0x8c, 0x23, 0xe0, 0xc0, 0xff, 0xee, 0x7f, 0x0e}, 0x02};
static const PROPERTYKEY JA_PKEY_AudioEndpoint_PhysicalSpeakers = {{0x1da5d803, 0xd492, 0x4edd, 0x8c, 0x23, 0xe0, 0xc0, 0xff, 0xee, 0x7f, 0x0e}, 0x03};
static const PROPERTYKEY JA_PKEY_AudioEndpoint_GUID = {{0x1da5d803, 0xd492, 0x4edd, 0x8c, 0x23, 0xe0, 0xc0, 0xff, 0xee, 0x7f, 0x0e}, 0x04};
static const PROPERTYKEY JA_PKEY_AudioEndpoint_Disable_SysFx = {{0x1da5d803, 0xd492, 0x4edd, 0x8c, 0x23, 0xe0, 0xc0, 0xff, 0xee, 0x7f, 0x0e}, 0x05};
static const PROPERTYKEY JA_PKEY_AudioEndpoint_FullRangeSpeakers = {{0x1da5d803, 0xd492, 0x4edd, 0x8c, 0x23, 0xe0, 0xc0, 0xff, 0xee, 0x7f, 0x0e}, 0x06};
static const PROPERTYKEY JA_PKEY_AudioEndpoint_Supports_EventDriven_Mode = {{0x1da5d803, 0xd492, 0x4edd, 0x8c, 0x23, 0xe0, 0xc0, 0xff, 0xee, 0x7f, 0x0e}, 0x07};
static const PROPERTYKEY JA_PKEY_AudioEndpoint_JackSubType = {{0x1da5d803, 0xd492, 0x4edd, 0x8c, 0x23, 0xe0, 0xc0, 0xff, 0xee, 0x7f, 0x0e}, 0x08};
static const PROPERTYKEY JA_PKEY_AudioEndpoint_Default_VolumeInDb = {{0x1da5d803, 0xd492, 0x4edd, 0x8c, 0x23, 0xe0, 0xc0, 0xff, 0xee, 0x7f, 0x0e}, 0x09};

static const IID JA_IID_IUnknown = {0x00000000, 0x0000, 0x0000, {0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46}};
static const IID JA_IDD_IAgileObject = {0x94EA2B94, 0xE9CC, 0x49E0, {0xC0, 0xFF, 0xEE, 0x64, 0xCA, 0x8F, 0x5B, 0x90}};

static const IID JA_IID_IAudioClient = {0x1CB9AD4C, 0xDBFA, 0x4C32, {0xB1, 0x78, 0xC2, 0xF5, 0x68, 0xA7, 0x03, 0xB2}};
static const IID JA_IID_IAudioClient2 = {0x726778CD, 0xF60A, 0x4EDA, {0x82, 0xDE, 0xE4, 0x76, 0x10, 0xCD, 0x78, 0xAA}};
static const IID JA_IID_IAudioClient3 = {0x7ED4EE07, 0x8E67, 0x4CD4, {0x8C, 0x1A, 0x2B, 0x7A, 0x59, 0x87, 0xAD, 0x42}};

static const IID JA_IID_IAudioRenderClient = {0xF294ACFC, 0x3146, 0x4483, {0xA7, 0xBF, 0xAD, 0xDC, 0xA7, 0xC2, 0x60, 0xE2}};
static const IID JA_IID_IAudioCaptureClient = {0xC8ADBD64, 0xE71E, 0x48A0, {0xA4, 0xDE, 0x18, 0x5C, 0x39, 0x5C, 0xD3, 0x17}};
static const IID JA_IID_IMMNotificationClient = {0x7991EEC9, 0x7E89, 0x4D85, {0x83, 0x90, 0x6C, 0x70, 0x3C, 0xEC, 0x60, 0xC0}};

static const IID IID_DEV_INTERFACE_AUDIO_RENDER = {0xE6327CAD, 0xDCEC, 0x4949, {0xAE, 0x8A, 0x99, 0x1E, 0x97, 0x6A, 0x79, 0xD2}};
static const IID IID_DEV_INTERFACE_AUDIO_CAPTURE = {0x2EEF81BE, 0x33FA, 0x4800, {0x96, 0x70, 0x1C, 0xD4, 0x74, 0x97, 0x2C, 0x3F}};

static const IID JA_CLSID_MMDeviceEnumerator = {0xBCDE0395, 0xE52F, 0x467C, {0x8E, 0x3D, 0xC4, 0x57, 0x92, 0x91, 0x69, 0x2E}};
static const IID JA_IID_IMMDeviceEnumerator = {0xA95664D2, 0x9614, 0x4F35, {0xA7, 0x46, 0xDE, 0x8D, 0xB6, 0x36, 0x17, 0xE6}};

//If the count is going to be greater than the max (4) then wrap around
typedef struct ja_device_buffer{
    //pointer devices_identifier[4]
    //pointer devices_name[4]
    QWORD count;
    //QWORD the type of buffer (render, capture, etc...)
}JA_DeviceBuffer;

//HRESULT (STDMETHODCALLTYPE * Stop)             (ma_IAudioClient* pThis);


/*
 * Dither only applies when we are reducing the bit depth (truncating the word length).
 *
 *                     /
 *                    /|\
 *                   / | \
 *                  /  |  \
 *                 /   |   \
 *                /    |    \
 *               /     |     \
 *              /      |      \
 *             /       |       \
 *            /        |        \
 *           /         |         \
 *          /          |          \
 *         /           |           \
 *        /            |            \
 *       /             |             \
 *      /              |              \
 * DitherMin---------------------------DitherMax
 *                     0
 * */

#define LCG_MOD 2_147_483_647
#define LCG_MUL 48_271
#define LCG_INC 0


enum ja_dither_mode{
    RECTANGLE = 0,
    TRIANGLE = 1,
}DitherMode;


typedef struct ja_dither{
    //Linear congruential generator dither parameters
    DWORD lcg_random;
    DWORD lcg_multiplier;
    DWORD lcg_increment;
    DWORD lcg_modulo;

    //Low-pass boxcar filter noise shaping parameters
    FLOAT32 quantization_error;
    FLOAT32 boxcar_constant;
}JADithering;

JA_LFORCE_INLINE DWORD JARandomLCG(JADithering* dithering){
    dithering->lcg_random = (dithering->lcg_multiplier * dithering->lcg_random + dithering->lcg_increment) % dithering->lcg_modulo;
    return dithering->lcg_random;
}

JA_LFORCE_INLINE FLOAT32 JARandomLCGFloat(JADithering* dithering){
    return (FLOAT32)(long)JARandomLCG(dithering) * (1.0f / (FLOAT32)0x7FFFFFFF);
}

JA_LFORCE_INLINE FLOAT JALinearInterpolation(float low, float high, float x){
    return low + (high - low) * x;
}

//Dithering + Noise Shaping
//We will optimize this.
JA_LFORCE_INLINE VOID JABitDepthF32ToS16Reference(void* dst, const void* src, QWORD count, JADithering* param){

    short* dst_samples = (short*)dst;
    const FLOAT32* src_samples = (FLOAT32*)src;

    FLOAT32 dither_min = 1.0f / -32768.0f;
    FLOAT32 dither_max = 1.0f / 32767.0f;

    FLOAT32 noise_shape_coef = param->boxcar_constant; //clamp this to 0.0 to 1.0

    FLOAT32 quantization_error = 0.0f;

    for (int i = 0; i < count; i += 1) {
        FLOAT32 seed = JARandomLCGFloat(param);
        FLOAT32 seed1 = JARandomLCGFloat(param);

        FLOAT32 triangular_pdf_a = JALinearInterpolation(dither_min, 0, seed);
        FLOAT32 triangular_pdf_b = JALinearInterpolation(0, dither_max, seed1);

        FLOAT32 dither = triangular_pdf_a + triangular_pdf_b;

        FLOAT32 target_sample = src_samples[i] + noise_shape_coef * quantization_error + dither;
        target_sample = ((target_sample < -1) ? -1 : (target_sample > 1) ? 1 : target_sample);

        target_sample = target_sample * 32767.0f;

        dst_samples[i] = (short)target_sample;

        quantization_error = src_samples[i] - target_sample;
    }
}

//We will optimize this.
JA_LFORCE_INLINE VOID JABitDepthS16ToF32Reference(void* dst,const void* src, QWORD count, JADithering* param){
    FLOAT* dst_samples = (FLOAT32*)dst;
    const short* src_samples = (short*)src;

    for (int i = 0; i < count; i+=1){
        dst_samples[i] = (FLOAT32)src_samples[i] * (1.0f / 32767.0f);
    }
}

typedef struct ja_context{

    JA_CoInitializeEx co_initialize;
    JA_CoCreateInstance co_create_instance;
    JA_CoUninitialize co_uninitialize;
    JA_CoTaskMemAlloc co_mem_alloc;
    JA_CoTaskMemFree co_mem_free;
    JA_CoTaskMemRealloc co_mem_realloc;
    JA_FreePropVariantArray co_free_prop_variants;
    JA_PropVariantClear co_clear_prop_variant;
    JA_PropVariantCopy co_copy_prop_variant;

    HMODULE ole_module;

    JADithering dither;

}JAContext;


JA_LFORCE_INLINE BOOL32 JAInitContextWin32(JAContext *context) {

    HMODULE ole_module = LoadLibraryExW(L"ole32.dll", NULL, JA_LOAD_LIBRARY_SEARCH_SYSTEM32);

    if (ole_module == NULL){
        return 1;
    }

    context->co_initialize = (JA_CoInitializeEx) GetProcAddress(ole_module, "CoInitializeEx");
    context->co_create_instance = (JA_CoCreateInstance) GetProcAddress(ole_module, "CoCreateInstance");
    context->co_uninitialize = (JA_CoUninitialize) GetProcAddress(ole_module, "CoUninitialize");
    context->co_mem_alloc = (JA_CoTaskMemAlloc) GetProcAddress(ole_module, "CoTaskMemAlloc");
    context->co_mem_free = (JA_CoTaskMemFree) GetProcAddress(ole_module, "CoTaskMemFree");
    context->co_mem_realloc = (JA_CoTaskMemRealloc) GetProcAddress(ole_module, "CoTaskMemRealloc");
    context->co_free_prop_variants = (JA_FreePropVariantArray) GetProcAddress(ole_module, "FreePropVariantArray");
    context->co_clear_prop_variant = (JA_PropVariantClear) GetProcAddress(ole_module, "PropVariantClear");
    context->co_copy_prop_variant = (JA_PropVariantCopy) GetProcAddress(ole_module, "PropVariantCopy");

    context->ole_module = ole_module;

    //Other module load below if needed.

    return 0;
}


JA_LFORCE_INLINE BOOL32 JAUnInitContextWin32(JAContext *context){
    BOOL32 result = 0;

    result |= FreeLibrary(context->ole_module);




    return result;
}



JA_LINLINE BOOL32 JAFetchDevices(){



}
//
////Buffer
//BOOL32 ja_fetch_devices(const DWORD audio_flow){
//
//
//    /*
//     * the core audio APIs are more restrictive because they require application streams to use formats that are the same
//     * as, or are closely related to, the formats used by the device (ENDPOINT). Thus, applications that use the core audio APIs to
//     * play or record audio streams might be required to do some or all of the conversions between stream formats
//     *
//     * An application that uses WASAPI to manage shared-mode streams can rely on the audio engine to perform only limited format conversions
//     * */
//
//
//    /*
//     * Thought:
//     * It is desirable for the application-defined sample rate to be the same as the device's native sample rate on WASAPI shared mode
//     * Otherwise we will need to handle resampling the audio data. Should we just make all the audio sample rate 48khz sample per second or
//     *
//     * The GetMixFormat method retrieves the stream format that the audio engine uses for its internal processing of shared-mode streams.
//     * The method always uses a WAVEFORMATEXTENSIBLE structure, instead of a stand-alone WAVEFORMATEX structure, to specify the format
//     * */
//
//    IMMDeviceEnumerator* enumerator = NULL;
//    IMMDeviceCollection* collection = NULL;
//    IMMDevice* endpoint_device = NULL; //Release the end point device.
//    IPropertyStore* endpoint_property = NULL;
//
//    if (audio_flow > 1){
//        return FALSE;
//    }
//    //IMMDevice::GetState
//    //a client can open a stream (for example, by obtaining an IAudioClient interface for the device) only on a device that is in the DEVICE_STATE_ACTIVE state
//
//    HRESULT s = CoInitializeEx(NULL, COINIT_MULTITHREADED | COINIT_DISABLE_OLE1DDE);
//    printf("%li",s);
//
//    //TODO:Khal be explicit with CLSCTX we don't want CLSCTX_REMOTE_SERVER
//    //https://learn.microsoft.com/en-us/windows/win32/api/wtypesbase/ne-wtypesbase-clsctx
//    CoCreateInstance(&JA_CLSID_MMDeviceEnumerator, NULL, CLSCTX_ALL, &JA_IID_IMMDeviceEnumerator, (LPVOID*)(&enumerator));
//
//    //Enumerate and find suitable audio endpoint to use (Only from host to device/endpoint)
//    enumerator->lpVtbl->EnumAudioEndpoints(enumerator, audio_flow, DEVICE_STATE_ACTIVE, &collection);
//
//    UINT collection_count;
//    collection->lpVtbl->GetCount(collection, &collection_count);
//
//    for (UINT i = 0; i < collection_count; ++i) {
//        PROPVARIANT property_variant;
//        PropVariantInit(&property_variant);
//
//        collection->lpVtbl->Item(collection, i, &endpoint_device);
//        endpoint_device->lpVtbl->OpenPropertyStore(endpoint_device, STGM_READ, &endpoint_property);
//
//        endpoint_property->lpVtbl->GetValue(endpoint_property, &JA_PKEY_Device_FriendlyName, &property_variant);
//
//        LPWSTR device_endpoint_id;
//        endpoint_device->lpVtbl->GetId(endpoint_device, &device_endpoint_id);
//
//        if (property_variant.vt == VT_LPWSTR){
//            //property_variant.pwszVal
//        }
//
//        wprintf(L"%ls\n", device_endpoint_id);
//        //add it to the array
//
//        //remove me when implemented shut down
//        CoTaskMemFree(device_endpoint_id);
//        PropVariantClear(&property_variant);
//        endpoint_property->lpVtbl->Release(endpoint_property);
//    }
//
//    collection->lpVtbl->Release(collection);
//    enumerator->lpVtbl->Release(enumerator);
//
//    CoUninitialize();
//    return 1;
//}

JA_LINLINE BOOL32 DisableDenormal(){
    DWORD previous_csr_flag = _mm_getcsr();
    _mm_setcsr(previous_csr_flag | _MM_FLUSH_ZERO_ON | _MM_DENORMALS_ZERO_ON);
    return 0;
}

BOOL32 JAInitContext(JAContext * context){
    BOOL32 return_res = 0;

    return_res |= JAInitContextWin32(context);
    DisableDenormal();


    HRESULT res = context->co_initialize(NULL, JA_COINIT_DEFAULT);


    printf("%li", res);
    //return_res |= ja_fetch_devices(0);

    return  return_res;
}

BOOL32 JAFreeContext(JAContext * context){
    return 0;
}


#endif //JOURNEY_AUDIO_LIBRARY_H
