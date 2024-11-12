#ifndef JOURNEY_AUDIO_LIBRARY_H
#define JOURNEY_AUDIO_LIBRARY_H

//TODO: -[T]khal -----------------------------------------------------------------------------------
#pragma comment(lib, "mincore.lib")

/*
 * Assumption:
 *
 *
 * Instruction Set:
 * All cpus using this library support the following intrinsics;
 * SSE, SSE2, SSE3, SSSE3, SSE4.1, SSE4.2, AVX, AVX2, FMA3 (Skylake : Zen)
 *
 * Format Constraint:
 * All Audio file passed through are 48000 or 44100 not higher nor lower.
 * Channel count is either 1 or 2
 * The Audio format is WAVE_FORMAT_PCM (integer) or WAVE_FORMAT_IEEE_FLOAT (floating)
 * The common precision of the audio format is 16 (integer) and 32 (floating point)
 *
 * Integer I16, float 32
 *
 * Allocation:
 *
 *
 * Error handling:
 * Procedure calls that take parameter will not check if the parameter/s are valid. The procedure will assume that all the parameters
 * are valid and with the range that is considered valid.
 *
 *
 * */

/*
 * In Windows 7, a new feature called low-latence mode has been added for streams in share mode.
 * In this mode, the audio engine runs in pull mode, in which there a significant reduction in latency.
 * This is very useful for communication applications that require low audio stream latency for faster streaming.
 *
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

#define JA_SUCCESS 0

typedef unsigned long long QWORD;

//Not really used as a 32 bit boolean.
typedef DWORD BOOL32;
typedef float FLOAT32;
typedef double FLOAT64;

#define JA_BYTE ((QWORD)(1))
#define JA_KILOBYTE ((QWORD(1) << 10)
#define JA_MEGABYTE ((QWORD)(1) << 20)
#define JA_GIGABYTE ((QWORD)(1) << 30)
#define JA_TERABYTE ((QWORD)(1) << 40)

///////////////////////////////////////////WIN32/////////////////////////////////////////////////////////
#define JA_COINIT_DEFAULT 0x0000000C /* COINIT_MULTITHREADED |  COINIT_DISABLE_OLE1DDE | COINIT_SPEED_OVER_MEMORY */

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

//The audio engine doesn't support the specified format.
#define JA_AUDIOCLNT_UNSUPPORTED_FORMAT ((HRESULT)0x88890008)

//The NumFramesWritten value exceeds the NumFrameRequested value specified in the previous IAudioRenderClient::GetBuffer procedure call.
#define JA_AUDIOCLNT_INVALID_SIZE ((HRESULT)0x88890009)

//The endpoint device is already in use. The device is being used in shared mode and the caller asked to use the device in exclusive or vis versa.
#define JA_AUDIOCLNT_DEVICE_IN_USE ((HRESULT)0x8889000A)

//Buffer cannot be accessed because a stream reset is in progress.
#define JA_AUDIOCLNT_BUFFER_OPERATION_PENDING ((HRESULT)0x8889000B)

//The thread is not registered.
#define JA_AUDIOCLNT_THREAD_NOT_REGISTERED ((HRESULT)0x8889000C)

//Indicates that the session spans more than one process.
#define JA_AUDIOCLNT_NO_SINGLE_PROCESS ((HRESULT)0x8889000D)

//The caller is requesting exclusive mode use of the endpoint device, but the user has disabled exclusive mode use of the device.
#define JA_AUDIOCLNT_EXLUSIVE_MODE_NOT_ALLOWED ((HRESULT)0x8889000E)

//The procedure failed to create the audio endpoint for either render or capture device. This occurs either if the audio endpoint device has been unplugged or the audio hardware or associated hardware resources have been tampered with
//(Reconfigured, disabled, removed, or otherwise made unavailable for use)
#define JA_AUDIOCLNT_ENDPOINT_CREATE_FAILED ((HRESULT)0x8889000F)

//The Windows audio service is not running.
#define JA_AUDIOCLNT_SERVICE_NOT_RUNNING ((HRESULT)0x88890010)

//The audio stream was not initialized for event-driven buffering.
#define JA_AUDIOCLNT_EVENTHANDLE_NOT_EXPECTED ((HRESULT)0x88890011)

//Exclusive mode only
#define JA_AUDIOCLNT_EXCLUSIVE_MODE_ONLY ((HRESULT)0x88890012)

//The AUDCLNT_STREAMFLAGS_EVENTCALLBACK flag is set but parameters hnsBufferDuration and hnsPeriodicity are not equal.
#define JA_AUDIOCLNT_BUFBURATION_PERIOD_NOT_EQUAL ((HRESULT)0x88890013)

//The audio stream is configured to use event-driven buffering, but the caller has not called IAudioClient::SetEventHandle to set the event handle on the stream.
#define JA_AUDIOCLNT_EVENTHANDLE_NOT_SET ((HRESULT)0x88890014)

//Indicates that the buffer has an incorrect size.
#define JA_AUDIOCLNT_INCORRECT_BUFFER_SIZE ((HRESULT)0x88890015)

//The audio endpoint device has been unplugged, or the audio hardware or associated hardware rIndicates that the process-pass duration exceeded the maximum CPU usage
#define JA_AUDIOCLNT_CPUUSAGE_EXCEEDED ((HRESULT)0x88890017)

//GetBuffer procedure failed to retrieve a data buffer and *ppData point to null.
#define JA_AUDIOCLNT_BUFFER_ERROR ((HRESULT)0x88890018)

//The requested buffer size is not aligned. Error may be returned from AUDCLNT_SHAREMODE_EXCLUSIVE and the AUDCLNT_STREAMFLAGS_EVENTCALLBACK flags.
#define JA_AUDIOCLNT_BUFFER_SIZE_NOT_ALIGNED ((HRESULT)0x88890019)

#define JA_STGM_READ 0x00000000L
#define JA_STGM_WRITE 0x00000001L
#define JA_STGM_READWRITE 0x00000002L



#define JA_AVRT_CRITICAL = 0x0000000000000002;
#define JA_AVRT_HIGH = 0x0000000000000001;
#define JA_AVRT_NORMAL = 0x0000000000000000;
#define JA_AVRT_LOW = 0xFFFFFFFFFFFFFFFF;
#define JA_AVRT_VERYLOW = 0xFFFFFFFFFFFFFFFE;


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

typedef struct ja_IUnknown ja_IUnknown;

typedef struct ja_IUnknownVtbl{
    HRESULT (STDMETHODCALLTYPE * ja_QueryInterface)(ja_IUnknown* self, const IID* const riid, void** ppvObject);
    ULONG (STDMETHODCALLTYPE * ja_AddRef)(ja_IUnknown* self);
    ULONG (STDMETHODCALLTYPE * ja_Release)(ja_IUnknown* self);
} ja_IUnknownVtbl;


struct ja_IUnknown{
    struct ja_IUnknownVtbl* lpVtbl;
};


//procedure pointers
typedef HRESULT (WINAPI * JA_CoInitializeEx)(void* pvReserved, DWORD dwCoInit);
typedef HRESULT (WINAPI * JA_CoCreateInstance)(const IID* const ref_clsid, ja_IUnknown* unknown_outer, DWORD cls_context, const IID* const iid, void* ppv);
//A thread must call CoUninitialize once for each successful call it has made to the CoInitialize or CoInitializeEx function, including any call that returns S_FALSE.
typedef void (WINAPI * JA_CoUninitialize)();
typedef void* (WINAPI * JA_CoTaskMemAlloc)(QWORD byte_size);
typedef void (WINAPI * JA_CoTaskMemFree)(void* mem_block);
typedef void* (WINAPI * JA_CoTaskMemRealloc)(void* mem_block, QWORD byte_size);
typedef HRESULT (WINAPI * JA_FreePropVariantArray)(DWORD count, PROPVARIANT * prop_variants);
typedef HRESULT (WINAPI * JA_PropVariantClear)(PROPVARIANT * prop_variant);
typedef HRESULT (WINAPI * JA_PropVariantCopy)(PROPVARIANT * dst_prop_variant, const PROPVARIANT * src_prop_variant);


typedef BOOL (WINAPI * JA_AvSetMmThreadPriority)(HANDLE avrt_handle, DWORD priority);
typedef HANDLE (WINAPI * JA_AvSetMmThreadCharacteristicsW)(LPCWSTR task_name, LPDWORD task_index);
typedef BOOL (WINAPI * JA_AvQuerySystemResponsiveness)(HANDLE avrt_handle, PULONG sys_responsive);
typedef BOOL (WINAPI * JA_AvRevertMmThreadCharacteristics)(HANDLE avrt_handle);

#define ja_FLUSH_ZERO_ENABLE 0x00008000
#define ja_DENORMALS_ENABLE 0x00000040
#define ja_FLUSH_ZERO_DISABLE 0xFFFF7FFF
#define ja_DENORMALS_DISABLE 0xFFFFFFBF

JA_LFORCE_INLINE BOOL32 DisableDenormal(){
    DWORD previous_csr_flag = _mm_getcsr();
    _mm_setcsr(previous_csr_flag | ja_FLUSH_ZERO_ENABLE | ja_DENORMALS_ENABLE);
    return 0;
}

JA_LFORCE_INLINE BOOL32 EnableDenormal(){
    DWORD previous_csr_flag = _mm_getcsr();
    _mm_setcsr(previous_csr_flag & ja_FLUSH_ZERO_DISABLE & ja_DENORMALS_DISABLE);

    return 0;
}

#define GUIDMatch(x,y) !memcpy(x,y, sizeof(GUID))


//////////////////////////////////////////Allocator///////////////////////////////////////////////////////
//We won't be using malloc and similar allocation procedure calls. Rather we will require the API to pass a buffer and the
//allocation in this api will use the buffer as a static arena allocation. Once the memory runs out then there is issues.

//Should we add align forward for the JASAllocator, since the alignment might be defaulted to 8 bytes, but
//this pointer buffer will contain a lot of data, such as sample buffer for the audio we want it to be aligned to
//YMM register (32 bytes)


#define JA_DEFAULT_COMMIT (JA_MEGABYTE * 64)
#define JA_DEFAULT_RESERVE (JA_GIGABYTE * 6)
#define JA_DEFAULT_ALIGNMENT (1 << 3)

typedef struct ja_static_allocator{
    QWORD index;
    QWORD length;
    QWORD capacity;
    QWORD alignment;

    VOID* buffer;
    QWORD unused[3];

}JASAllocator;

JA_LFORCE_INLINE BOOL32 IsPowerOfTwo(QWORD x){
    return (x & (x-1)) == 0;
}

JA_LFORCE_INLINE BOOL32 IsAligned(QWORD x, const QWORD alignment){
    QWORD modulo = alignment - 1;

    if (alignment & modulo){
        return 0;
    }

    return (x & modulo) == 0;
}


JA_LFORCE_INLINE QWORD RoundDownPowerTwo(QWORD x){
    x = x | (x >> 1);
    x = x | (x >> 2);
    x = x | (x >> 4);
    x = x | (x >> 8);
    x = x | (x >> 16);
    return x - (x >> 1);
}

JA_LFORCE_INLINE QWORD RoundUpPowerTwo(QWORD x){
    x = x -1;
    x = x | (x >> 1);
    x = x | (x >> 2);
    x = x | (x >> 4);
    x = x | (x >> 8);
    x = x | (x >> 16);
    return x + 1;
}

JA_LFORCE_INLINE BOOL32 InitCircularBuffer(){

}

JA_LFORCE_INLINE BOOL32 ClearCircularBuffer(){

}

JA_LFORCE_INLINE BOOL32 ReleaseCircularBuffer(){

}



JA_LFORCE_INLINE BOOL32 InitAllocator(JASAllocator* allocator, const QWORD commit, const QWORD reserved, const QWORD alignment){
    //We will do a virtual allocation
    //If the memory is being reserved, the specified address is rounded down to the nearest multiple of the allocation granularity
    //If the memory is already reserved and is being committed, the address is rounded down to the next page boundary
    //Memory allocated by this function is automatically initialized to zero.
    QWORD target_commit_size = JA_DEFAULT_COMMIT;
    QWORD target_reserve_size = JA_DEFAULT_RESERVE;
    QWORD target_alignment = JA_DEFAULT_ALIGNMENT;

    SYSTEM_INFO sys_info;
    GetSystemInfo(&sys_info);

    DWORD page_size = sys_info.dwPageSize;
    DWORD granularity = sys_info.dwAllocationGranularity;

    if (commit != 0){
        QWORD pages = (commit + page_size - 1) >> 12;
        target_commit_size = pages << 12;
    }

    if (reserved != 0) {
        QWORD reservation = (reserved + granularity - 1) >> 16;
        target_reserve_size = reservation << 16;
    }

    if (alignment != 0){
        QWORD forward_alignment = RoundUpPowerTwo(alignment);
        target_alignment = forward_alignment;
    }

    if(target_commit_size > target_reserve_size){
        //return an error code.
        return 1;
    }

    VOID* reserved_ptr = VirtualAlloc2(NULL, NULL, target_reserve_size, MEM_RESERVE, PAGE_READWRITE, NULL, 0);
    VOID* ptr = VirtualAlloc2(NULL, reserved_ptr, target_commit_size, MEM_COMMIT, PAGE_READWRITE, NULL, 0);

    allocator->index = 0;
    allocator->length = target_commit_size;
    allocator->capacity =  target_reserve_size;
    allocator->alignment = target_alignment;

    allocator->buffer = ptr;

    return 0;

}

JA_LFORCE_INLINE BOOL32 ReleaseAllocator(){

}

JA_LFORCE_INLINE BOOL32 ClearAllocate(JASAllocator* allocator){
    allocator->index = 0;

    return 0;
}


//Allocate, Free, ReAlloc, Copy
JA_LFORCE_INLINE VOID* PushAllocate(JASAllocator* allocator,const QWORD size,const QWORD alignment){

    if (allocator->index + size >= allocator->length){
        return NULL;
    }



}


JA_LFORCE_INLINE BOOL32 PopAllocate(JASAllocator* allocator,const QWORD size){


}

JA_LFORCE_INLINE DWORD GetAllocatePos(JASAllocator* allocator){

}

///////////////////////////////////////////DECODE////////////////////////////////////////////////////////






///////////////////////////////////////////WASAPI////////////////////////////////////////////////////////

#define JAPrimarySampleRate 48000
#define JASecondarySampleRate 44100

#define MinChannel 1
#define MaxChannel 2

#define ja_WAVE_FORMAT_IEEE_FLOAT 0x0003
#define ja_WAVE_FORMAT_PCM 0x0001
#define ja_WAVE_FORMAT_EXTENSIBLE 0xFFFE


#define ja_FORM_FACTOR_REMOTENETWORKDEVICE 0x00000000
#define ja_FORM_FACTOR_SPEAKERS 0x00000001
#define ja_FORM_FACTOR_LINELEVEL 0x00000002
#define ja_FORM_FACTOR_HEADPHONE 0x00000003
#define ja_FORM_FACTOR_MICROPHONE 0x00000004
#define ja_FORM_FACTOR_HEADSET 0x00000005
#define ja_FORM_FACTOR_HANDSET 0x00000006
#define ja_FORM_FACTOR_UNKNOWN_DP 0x00000007
#define ja_FORM_FACTOR_SPDIF 0x00000008
#define ja_FORM_FACTOR_DADD 0x00000009
#define ja_FORM_FACTOR_UNKNOWN 0x0000000A

//Query Masks
#define ja_AUDIO_FORMAT_U8 0x00000001
#define ja_AUDIO_FORMAT_S16 0x00000002
#define ja_AUDIO_FORMAT_S24 0x00000003
#define ja_AUDIO_FORMAT_S32 0x00000004
#define ja_AUDIO_FORMAT_F32 0x00000008
#define ja_AUDIO_FORMAT_F64 0x00000010
#define ja_AUDIO_SPEAKER_MONO 0x00000020
#define ja_AUDIO_SPEAKER_STEREO 0x00000040
#define ja_AUDIO_EVENT_DRIVEN 0x00000080
#define ja_AUDIO_SPEAKERS 0x00000100
#define ja_AUDIO_HEADPHONE 0x00000200
#define ja_AUDIO_MICROPHONE 0x00000400
#define ja_AUDIO_HEADSET 0x00000800



#define ja_DEVICE_STATE_ACTIVE 0x0000000000000001
#define ja_DEVICE_STATE_DISABLE 0x0000000000000002
#define ja_DEVICE_STATE_NOTPRESENT 0x0000000000000004
#define ja_DEVICE_STATE_UNPLUGGED 0x0000000000000008
#define ja_DEVICE_STATEMASK_ALL 0x000000000000000F


/*
 *
 * Audio format type:
 * S16
 *
 */

typedef enum ja_audio_format{
    U8 = 0x00000001,
    S16 = 0x00000002,
    S24 = 0x00000003,
    S32 = 0x00000004,
    F32 = 0x00000008,
    F64 = 0x00000010,
}ja_AudioFormat;

typedef enum ja_audio_channel{
    Unknown_Channel = 0x00000000,
    Mono = 0x00000001,
    Stereo = 0x00000002,
}ja_AudioChannel;

typedef enum ja_mmcss_task_key {
    Audio,
    Games,
    Playback,
    ProAudio,
}ja_MMCSSTaskKey;

typedef enum ja_query_profile{
    TEMP,

}ja_QueryProfile;

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

static const GUID JA_KSDATAFORMAT_SUBTYPE_PCM = {0x00000001, 0x0000, 0x0010, {0x80, 0x00, 0x00, 0xAA, 0x00, 0x38, 0x9B, 0x71}};
static const GUID JA_KSDATA_FORMAT_SUBTYPE_IEEE_FLOAT = {0x00000003, 0x0000, 0x0010, {0x80, 0x00, 0x00, 0xAA, 0x00, 0x38, 0x9B, 0x71 } };

typedef enum ja_EDataFlow{
    Render = 0,
    Capture,
    All,
    EDataFlow_count
}ja_EDataFlow;

typedef enum ja_ERole{
    Console = 0,
    Multimedia,
    Communications,
    ERole_count
}ja_ERole;

typedef struct ja_IMMDeviceEnumerator ja_IMMDeviceEnumerator;
typedef struct ja_IMMDeviceCollection ja_IMMDeviceCollection;
typedef struct ja_IMMDevice ja_IMMDevice;
typedef struct ja_IMMNotificationClient ja_IMMNotificationClient;
typedef struct ja_IPropertyStore ja_IPropertyStore;


typedef struct ja_IMMDeviceEnumeratorVtbl{
    HRESULT (STDMETHODCALLTYPE * ja_QueryInterface)(ja_IMMDeviceEnumerator* self, const IID* const riid, void** ppvObject);
    ULONG (STDMETHODCALLTYPE * ja_AddRef)(ja_IMMDeviceEnumerator* self);
    ULONG (STDMETHODCALLTYPE * ja_Release)(ja_IMMDeviceEnumerator* self);

    HRESULT (STDMETHODCALLTYPE * ja_EnumAudioEndpoints)(ja_IMMDeviceEnumerator* self, ja_EDataFlow dataFlow, DWORD dwStateMask, ja_IMMDeviceCollection** ppDevices);
    HRESULT (STDMETHODCALLTYPE * ja_GetDefaultAudioEndpoint)(ja_IMMDeviceEnumerator* self, ja_EDataFlow dataFlow, ja_ERole role, IMMDevice** ppEndpoint);
    HRESULT (STDMETHODCALLTYPE * ja_GetDevice)(ja_IMMDeviceEnumerator* self, LPCWSTR pwstrId, IMMDevice** ppDevice);
    HRESULT (STDMETHODCALLTYPE * ja_RegisterEndpointNotificationCallback)(ja_IMMDeviceEnumerator* self, IMMNotificationClient* pClient);
    HRESULT (STDMETHODCALLTYPE * ja_UnregisterEndpointNotificationCallback)(ja_IMMDeviceEnumerator* self, IMMNotificationClient* pClient);

} ja_IMMDeviceEnumeratorVtbl;

typedef struct ja_IMMDeviceCollectionVtbl{
    HRESULT (STDMETHODCALLTYPE * ja_QueryInterface)(ja_IMMDeviceCollection* self, const IID* const riid, void** ppvObject);
    ULONG (STDMETHODCALLTYPE * ja_AddRef)(ja_IMMDeviceCollection* self);
    ULONG (STDMETHODCALLTYPE * ja_Release)(ja_IMMDeviceCollection* self);

    HRESULT (STDMETHODCALLTYPE * ja_GetCount)(ja_IMMDeviceCollection* self, UINT* pcDevice);
    HRESULT (STDMETHODCALLTYPE * ja_Item)(ja_IMMDeviceCollection* self, UINT nDevice, ja_IMMDevice** ppDevice);

}ja_IMMDeviceCollectionVtbl;

typedef struct ja_IMMDeviceVtbl{
    HRESULT (STDMETHODCALLTYPE * ja_QueryInterface)(ja_IMMDevice* self, const IID* const riid, void** ppvObject);
    ULONG (STDMETHODCALLTYPE * ja_AddRef)(ja_IMMDevice* self);
    ULONG (STDMETHODCALLTYPE * ja_Release)(ja_IMMDevice* self);


    HRESULT (STDMETHODCALLTYPE * ja_Activate)(ja_IMMDevice* self, const IID* const iid, DWORD dwClsCtx, PROPVARIANT pActivationParams, void** ppInterface);
    HRESULT (STDMETHODCALLTYPE * ja_OpenPropertyStore)(ja_IMMDevice* self, DWORD stgmAccess, ja_IPropertyStore** ppProperties);
    HRESULT (STDMETHODCALLTYPE * ja_GetId)(IMMDevice* self, LPWSTR* ppstrId);
    HRESULT (STDMETHODCALLTYPE * ja_GetState)(IMMDevice* self, DWORD* pwState);

}ja_IMMDeviceVtbl;


typedef struct ja_IMMNotificationClientVtbl{
    HRESULT (STDMETHODCALLTYPE * ja_QueryInterface)(ja_IMMNotificationClient* self, const IID* const riid, void** ppvObject);
    ULONG (STDMETHODCALLTYPE * ja_AddRef)(ja_IMMNotificationClient* self);
    ULONG (STDMETHODCALLTYPE * ja_Release)(ja_IMMNotificationClient* self);

    HRESULT (STDMETHODCALLTYPE * ja_OnDeviceStateChanged)(IMMNotificationClient* self, LPCWSTR pwstrDeviceId, DWORD dwNewState);
    HRESULT (STDMETHODCALLTYPE * ja_OnDeviceAdded)(IMMNotificationClient* self, LPCWSTR pwstrDeviceId);
    HRESULT (STDMETHODCALLTYPE * ja_OnDeviceRemoved)(IMMNotificationClient* self, LPCWSTR pwstrDeviceId);
    HRESULT (STDMETHODCALLTYPE * ja_OnDefaultDeviceChanged)(IMMNotificationClient* self, ja_EDataFlow flow, ja_ERole role, LPCWSTR pwstrDefaultDeviceId);
    HRESULT (STDMETHODCALLTYPE * ja_OnPropertyValueChanged)(IMMNotificationClient* self, LPCWSTR pwstrDeviceId, const PROPERTYKEY key);

}ja_IMMNotificationClientVtbl;


typedef struct ja_IPropertyStoreVtbl{
    HRESULT (STDMETHODCALLTYPE * ja_QueryInterface)(ja_IPropertyStore* self, const IID* const riid, void** ppvObject);
    ULONG (STDMETHODCALLTYPE * ja_AddRef)(ja_IPropertyStore* self);
    ULONG (STDMETHODCALLTYPE * ja_Release)(ja_IPropertyStore* self);

    HRESULT (STDMETHODCALLTYPE * ja_GetCount)(ja_IPropertyStore* self, DWORD* cProps);
    HRESULT (STDMETHODCALLTYPE * ja_GetAt)(ja_IPropertyStore* self, DWORD iProp, PROPERTYKEY* pKey);
    HRESULT (STDMETHODCALLTYPE * ja_GetValue)(ja_IPropertyStore* self, const PROPERTYKEY* const key, PROPVARIANT* pvariant);
    HRESULT (STDMETHODCALLTYPE * ja_SetValue)(ja_IPropertyStore* self, const PROPERTYKEY* const key, const PROPVARIANT* const propvar);
    HRESULT (STDMETHODCALLTYPE * ja_Commit)(ja_IPropertyStore* self);

}ja_IPropertyStoreVtbl;


struct ja_IMMDeviceEnumerator{
    struct ja_IMMDeviceEnumeratorVtbl* lpVtbl;
};

struct ja_IMMDeviceCollection{
    struct ja_IMMDeviceCollectionVtbl* lpVtbl;
};

struct ja_IMMDevice{
    struct ja_IMMDeviceVtbl* lpVtbl;
};

struct ja_IMMNotificationClient{
    struct ja_IMMNotificationClientVtbl* lpVtbl;
};

struct ja_IPropertyStore{
    struct ja_IPropertyStoreVtbl* lpVtbl;
};


JA_LFORCE_INLINE BOOL32 FormatSupported(DWORD format){



}

JA_LFORCE_INLINE BOOL32 ChannelSupported(DWORD channel){


}

JA_LFORCE_INLINE BOOL32 SampleRateSupported(DWORD sample_rate){


}

JA_LFORCE_INLINE LPCWSTR MMCSSRegisterTaskToWide(ja_MMCSSTaskKey key){
    switch (key){
        case Audio:
        {
            return L"Audio";
        }
        case Games:
        {
            return L"Games";
        }
        case Playback:
        {
            return L"Playback";
        }
        case ProAudio:
        {
            return L"Pro Audio";
        }
    }
}

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

#define DEFAULT_LCG_MOD 2147483647
#define DEFAULT_LCG_MUL 48271
#define DEFAULT_LCG_INC 0
#define DEFAULT_BOXCAR_CONSTANT 0.8

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

JA_LFORCE_INLINE JADithering JAInitDitherParamDefault(){
    JADithering dither_param;

    dither_param.lcg_random = 0;
    dither_param.lcg_multiplier = DEFAULT_LCG_MUL;
    dither_param.lcg_increment = DEFAULT_LCG_INC;
    dither_param.lcg_modulo = DEFAULT_LCG_MOD;
    dither_param.quantization_error = 0;
    dither_param.boxcar_constant = DEFAULT_BOXCAR_CONSTANT;

    return dither_param;
}

JA_LFORCE_INLINE JADithering JAInitDitherParam(const DWORD multiplier,const DWORD increment,const DWORD modulo,const FLOAT32 boxcar_coef){
    JADithering dither_param;

    dither_param.lcg_random = 0;
    dither_param.lcg_multiplier = multiplier;
    dither_param.lcg_increment =  increment;
    dither_param.lcg_modulo = modulo;
    dither_param.quantization_error = 0;
    dither_param.boxcar_constant = boxcar_coef;

    return  dither_param;
}

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


    if (IsAligned((QWORD) dst, 32) & IsAligned((QWORD) src, 32)){
        //YMM register


        return;
    }


    //Default

    short* dst_samples = (short*)dst;
    const FLOAT32* src_samples = (FLOAT32*)src;

    FLOAT32 dither_min = -0.000030517578125f; // (1.0f / -32768.0f)
    FLOAT32 dither_max = 0.0000305185f; // (1.0f / 32767.0f)

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

    if (IsAligned((QWORD) src, 32) & IsAligned((QWORD) dst, 32)){
        //We can use YMM register



        return;
    }

    //Default

    const short* src_samples = (short*)src;

    for (int i = 0; i < count; i+=1){
        dst_samples[i] = (FLOAT32)src_samples[i] * (1.0f / 32767.0f);
    }
}

typedef struct ja_context{

    JA_CoInitializeEx ja_CoInitialize;
    JA_CoCreateInstance ja_CoCreateInstance;
    JA_CoUninitialize ja_CoUninitialize;
    JA_CoTaskMemAlloc ja_CoMemAlloc;
    JA_CoTaskMemFree ja_CoMemFree;
    JA_CoTaskMemRealloc ja_CoMemRealloc;
    JA_FreePropVariantArray ja_CoFreePropVariants;
    JA_PropVariantClear ja_CoClearPropVariant;
    JA_PropVariantCopy ja_CoCopyPropVariant;

    HMODULE ole_module;

    JA_AvSetMmThreadPriority ja_AvSetMmThreadPriority;
    JA_AvSetMmThreadCharacteristicsW  ja_AvSetMmThreadCharacteristic;
    JA_AvQuerySystemResponsiveness ja_AvQuerySystemResponsiveness;
    JA_AvRevertMmThreadCharacteristics ja_AvRevertThreadCharacteristic;

    HMODULE avrt_module;
    JADithering dither;


}JAContext;


JA_LFORCE_INLINE BOOL32 JAInitContextWin32(JAContext *context) {

    HMODULE ole_module = LoadLibraryExW(L"ole32.dll", NULL, JA_LOAD_LIBRARY_SEARCH_SYSTEM32);
    HMODULE avrt_module = LoadLibraryExW(L"avrt.dll", NULL, JA_LOAD_LIBRARY_SEARCH_SYSTEM32);

    if (ole_module == NULL || avrt_module == NULL){
        return 1;
    }

    //OLE32
    context->ja_CoInitialize = (JA_CoInitializeEx) GetProcAddress(ole_module, "CoInitializeEx");
    context->ja_CoCreateInstance = (JA_CoCreateInstance) GetProcAddress(ole_module, "CoCreateInstance");
    context->ja_CoUninitialize = (JA_CoUninitialize) GetProcAddress(ole_module, "CoUninitialize");
    context->ja_CoMemAlloc = (JA_CoTaskMemAlloc) GetProcAddress(ole_module, "CoTaskMemAlloc");
    context->ja_CoMemFree = (JA_CoTaskMemFree) GetProcAddress(ole_module, "CoTaskMemFree");
    context->ja_CoMemRealloc = (JA_CoTaskMemRealloc) GetProcAddress(ole_module, "CoTaskMemRealloc");
    context->ja_CoFreePropVariants = (JA_FreePropVariantArray) GetProcAddress(ole_module, "FreePropVariantArray");
    context->ja_CoClearPropVariant = (JA_PropVariantClear) GetProcAddress(ole_module, "PropVariantClear");
    context->ja_CoCopyPropVariant = (JA_PropVariantCopy) GetProcAddress(ole_module, "PropVariantCopy");

    context->ole_module = ole_module;

    //AVRT
    context->ja_AvSetMmThreadPriority = (JA_AvSetMmThreadPriority) GetProcAddress(avrt_module, "AvSetMmThreadPriority");
    context->ja_AvSetMmThreadCharacteristic = (JA_AvSetMmThreadCharacteristicsW) GetProcAddress(avrt_module, "AvSetMmThreadCharacteristicsW");
    context->ja_AvQuerySystemResponsiveness = (JA_AvQuerySystemResponsiveness) GetProcAddress(avrt_module, "AvQuerySystemResponsiveness");
    context->ja_AvRevertThreadCharacteristic = (JA_AvRevertMmThreadCharacteristics) GetProcAddress(avrt_module, "AvRevertMmThreadCharacteristics");

    context->avrt_module = avrt_module;

    //Other module load below if needed.

    return context->ja_CoInitialize(NULL, JA_COINIT_DEFAULT);
}

JA_LFORCE_INLINE ja_AudioChannel WaveFormatexToChannel(WAVEFORMATEX* waveformatex){
    return (ja_AudioChannel)((DWORD)(waveformatex->nChannels) & 0x00000003);
}

JA_LFORCE_INLINE ja_AudioFormat WaveFormatexToFormat(WAVEFORMATEX* waveformatex){
    DWORD sub_format_type = 0x00000000;

    if (waveformatex->wFormatTag == ja_WAVE_FORMAT_EXTENSIBLE && waveformatex->cbSize >= 0x0016){
        WAVEFORMATEXTENSIBLE* waveformat_extensible = (WAVEFORMATEXTENSIBLE*)(waveformatex);

        if (waveformat_extensible->Samples.wValidBitsPerSample % 0x0008 > 0){
            return 0;
        }

        sub_format_type = waveformat_extensible->SubFormat.Data1;
    }

    DWORD format_mask = (DWORD)(waveformatex->wBitsPerSample) >> 0x00000003;

    if (waveformatex->wFormatTag == ja_WAVE_FORMAT_IEEE_FLOAT || sub_format_type == 0x00000003){
        format_mask <<= 1;
    }

    return (ja_AudioFormat)(format_mask);
}




//This will be used as initializing a specific audio endpoint that matches the profile.
JA_LFORCE_INLINE BOOL32 JAQueryEndpoints(JAContext* ctx, ja_EDataFlow role, const DWORD profile){
    //void* satisfied_endpoints = AppendAllocate(ctx->static_allocator, 36, 8);

    UINT endpoint_device_count;
    ja_IMMDeviceEnumerator* device_enumerator;
    ja_IMMDeviceCollection* device_collection;

    ctx->ja_CoCreateInstance(&JA_CLSID_MMDeviceEnumerator, NULL, CLSCTX_ALL, &JA_IID_IMMDeviceEnumerator, (LPVOID*)(&device_enumerator));
    device_enumerator->lpVtbl->ja_EnumAudioEndpoints(device_enumerator, role, ja_DEVICE_STATE_ACTIVE, &device_collection);
    device_collection->lpVtbl->ja_GetCount(device_collection, &endpoint_device_count);

    for (int i = 0; i < endpoint_device_count; i += 1) {
        DWORD valid_device_mask = 0x00000000;

        ja_IMMDevice* endpoint_device;
        ja_IPropertyStore* prop_store;
        PROPVARIANT prop_variant;

        memset(&prop_variant, 0, sizeof(PROPVARIANT));

        device_collection->lpVtbl->ja_Item(device_collection, i, &endpoint_device);
        endpoint_device->lpVtbl->ja_OpenPropertyStore(endpoint_device, JA_STGM_READ, &prop_store);

        prop_store->lpVtbl->ja_GetValue(prop_store, &JA_PKEY_AudioEngine_OEMFormat, &prop_variant);

        if (prop_variant.vt == VT_BLOB){
            WAVEFORMATEX* device_wave_format = (WAVEFORMATEX*)prop_variant.blob.pBlobData;

            ja_AudioFormat format = WaveFormatexToFormat(device_wave_format);
            ja_AudioChannel channel = WaveFormatexToChannel(device_wave_format);

            valid_device_mask = format | (channel << 0x05);
        }

        prop_store->lpVtbl->ja_GetValue(prop_store, &JA_PKEY_AudioEndpoint_Supports_EventDriven_Mode, &prop_variant);

        if (prop_variant.vt == VT_UI4){
            valid_device_mask |= (prop_variant.uintVal << 0x07);
        }

        prop_store->lpVtbl->ja_GetValue(prop_store, &JA_PKEY_AudioEndpoint_FormFactor, &prop_variant);

        if (prop_variant.vt == VT_UI4){
            switch (prop_variant.uintVal) {
                case ja_FORM_FACTOR_SPEAKERS:
                {
                    valid_device_mask |= 0x00000100;
                    break;
                }
                case ja_FORM_FACTOR_HEADPHONE:
                {
                    valid_device_mask |= 0x00000200;
                    break;
                }
                case ja_FORM_FACTOR_MICROPHONE:
                {
                    valid_device_mask |= 0x00000400;
                    break;
                }
                case ja_FORM_FACTOR_HEADSET:
                {
                    valid_device_mask |= 0x00000800;
                    break;
                }
            }
        }


        printf(" %lu\n", valid_device_mask);

        if (valid_device_mask == profile){
            //if all the condition query are meet
            //endpoint_device->lpVtbl->ja_GetId(endpoint_device,id)
            //satisfied_endpoints[?] = id //Copy id to the satisfied endpoints
        }

        ctx->ja_CoClearPropVariant(&prop_variant);

        prop_store->lpVtbl->ja_Release(prop_store);
        endpoint_device->lpVtbl->ja_Release(endpoint_device);
    }

    device_collection->lpVtbl->ja_Release(device_collection);
    device_enumerator->lpVtbl->ja_Release(device_enumerator);

    //return the satisfied endpoints
    return 0;
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


BOOL32 JAInitContext(JAContext* context, const DWORD profile, const DWORD commit_size, const DWORD reserve_size){
    JAContext* ctx = context;
    JASAllocator allocator;

    InitAllocator(&allocator, commit_size, reserve_size, 8);

    if (ctx == NULL){
      //ctx = (JAContext*)AppendAllocate(&allocator, sizeof(JAContext), 8);
    }

    if (JAInitContextWin32(context)){
        return 1;
    }


    DisableDenormal();

    if (profile){
        JAQueryEndpoints(context, Render, profile);
        //Get the first one
    }else{
        //Get the first default device endpoint.
    }


    return 0;
}

BOOL32 JAFreeContext(JAContext * context){
    BOOL32 result = 0;

    EnableDenormal();

    context->ja_CoUninitialize();

    result |= FreeLibrary(context->ole_module);
    result |= FreeLibrary(context->avrt_module);



    return result;

    return 0;
}


#endif //JOURNEY_AUDIO_LIBRARY_H
