#include <iostream>

/*******************************************************************************

WIN32 COMMON

*******************************************************************************/
#if defined(MA_WIN32)
#if defined(MA_WIN32_DESKTOP) || defined(MA_WIN32_GDK)
    #define ma_CoInitializeEx(pContext, pvReserved, dwCoInit)                          ((pContext->win32.CoInitializeEx) ? ((MA_PFN_CoInitializeEx)pContext->win32.CoInitializeEx)(pvReserved, dwCoInit) : ((MA_PFN_CoInitialize)pContext->win32.CoInitialize)(pvReserved))
    #define ma_CoUninitialize(pContext)                                                ((MA_PFN_CoUninitialize)pContext->win32.CoUninitialize)()
    #define ma_CoCreateInstance(pContext, rclsid, pUnkOuter, dwClsContext, riid, ppv)  ((MA_PFN_CoCreateInstance)pContext->win32.CoCreateInstance)(rclsid, pUnkOuter, dwClsContext, riid, ppv)
    #define ma_CoTaskMemFree(pContext, pv)                                             ((MA_PFN_CoTaskMemFree)pContext->win32.CoTaskMemFree)(pv)
    #define ma_PropVariantClear(pContext, pvar)                                        ((MA_PFN_PropVariantClear)pContext->win32.PropVariantClear)(pvar)
#else
    #define ma_CoInitializeEx(pContext, pvReserved, dwCoInit)                          CoInitializeEx(pvReserved, dwCoInit)
    #define ma_CoUninitialize(pContext)                                                CoUninitialize()
    #define ma_CoCreateInstance(pContext, rclsid, pUnkOuter, dwClsContext, riid, ppv)  CoCreateInstance(rclsid, pUnkOuter, dwClsContext, riid, ppv)
    #define ma_CoTaskMemFree(pContext, pv)                                             CoTaskMemFree(pv)
    #define ma_PropVariantClear(pContext, pvar)                                        PropVariantClear(pvar)
#endif

#if !defined(MAXULONG_PTR) && !defined(__WATCOMC__)
typedef size_t DWORD_PTR;
#endif

#if !defined(WAVE_FORMAT_1M08)
#define WAVE_FORMAT_1M08    0x00000001
#define WAVE_FORMAT_1S08    0x00000002
#define WAVE_FORMAT_1M16    0x00000004
#define WAVE_FORMAT_1S16    0x00000008
#define WAVE_FORMAT_2M08    0x00000010
#define WAVE_FORMAT_2S08    0x00000020
#define WAVE_FORMAT_2M16    0x00000040
#define WAVE_FORMAT_2S16    0x00000080
#define WAVE_FORMAT_4M08    0x00000100
#define WAVE_FORMAT_4S08    0x00000200
#define WAVE_FORMAT_4M16    0x00000400
#define WAVE_FORMAT_4S16    0x00000800
#endif

#if !defined(WAVE_FORMAT_44M08)
#define WAVE_FORMAT_44M08   0x00000100
#define WAVE_FORMAT_44S08   0x00000200
#define WAVE_FORMAT_44M16   0x00000400
#define WAVE_FORMAT_44S16   0x00000800
#define WAVE_FORMAT_48M08   0x00001000
#define WAVE_FORMAT_48S08   0x00002000
#define WAVE_FORMAT_48M16   0x00004000
#define WAVE_FORMAT_48S16   0x00008000
#define WAVE_FORMAT_96M08   0x00010000
#define WAVE_FORMAT_96S08   0x00020000
#define WAVE_FORMAT_96M16   0x00040000
#define WAVE_FORMAT_96S16   0x00080000
#endif

#ifndef SPEAKER_FRONT_LEFT
#define SPEAKER_FRONT_LEFT            0x1
#define SPEAKER_FRONT_RIGHT           0x2
#define SPEAKER_FRONT_CENTER          0x4
#define SPEAKER_LOW_FREQUENCY         0x8
#define SPEAKER_BACK_LEFT             0x10
#define SPEAKER_BACK_RIGHT            0x20
#define SPEAKER_FRONT_LEFT_OF_CENTER  0x40
#define SPEAKER_FRONT_RIGHT_OF_CENTER 0x80
#define SPEAKER_BACK_CENTER           0x100
#define SPEAKER_SIDE_LEFT             0x200
#define SPEAKER_SIDE_RIGHT            0x400
#define SPEAKER_TOP_CENTER            0x800
#define SPEAKER_TOP_FRONT_LEFT        0x1000
#define SPEAKER_TOP_FRONT_CENTER      0x2000
#define SPEAKER_TOP_FRONT_RIGHT       0x4000
#define SPEAKER_TOP_BACK_LEFT         0x8000
#define SPEAKER_TOP_BACK_CENTER       0x10000
#define SPEAKER_TOP_BACK_RIGHT        0x20000
#endif

/*
Implement our own version of MA_WAVEFORMATEXTENSIBLE so we can avoid a header. Be careful with this
because MA_WAVEFORMATEX has an extra two bytes over standard WAVEFORMATEX due to padding. The
standard version uses tight packing, but for compiler compatibility we're not doing that with ours.
*/
typedef struct
{
    WORD wFormatTag;
    WORD nChannels;
    DWORD nSamplesPerSec;
    DWORD nAvgBytesPerSec;
    WORD nBlockAlign;
    WORD wBitsPerSample;
    WORD cbSize;
} MA_WAVEFORMATEX;

typedef struct
{
    WORD wFormatTag;
    WORD nChannels;
    DWORD nSamplesPerSec;
    DWORD nAvgBytesPerSec;
    WORD nBlockAlign;
    WORD wBitsPerSample;
    WORD cbSize;
    union
    {
        WORD wValidBitsPerSample;
        WORD wSamplesPerBlock;
        WORD wReserved;
    } Samples;
    DWORD dwChannelMask;
    GUID SubFormat;
} MA_WAVEFORMATEXTENSIBLE;



#ifndef WAVE_FORMAT_EXTENSIBLE
#define WAVE_FORMAT_EXTENSIBLE  0xFFFE
#endif

#ifndef WAVE_FORMAT_PCM
#define WAVE_FORMAT_PCM         1
#endif

#ifndef WAVE_FORMAT_IEEE_FLOAT
#define WAVE_FORMAT_IEEE_FLOAT  0x0003
#endif

/* Converts an individual Win32-style channel identifier (SPEAKER_FRONT_LEFT, etc.) to miniaudio. */
static ma_uint8 ma_channel_id_to_ma__win32(DWORD id)
{
    switch (id)
    {
        case SPEAKER_FRONT_LEFT:            return MA_CHANNEL_FRONT_LEFT;
        case SPEAKER_FRONT_RIGHT:           return MA_CHANNEL_FRONT_RIGHT;
        case SPEAKER_FRONT_CENTER:          return MA_CHANNEL_FRONT_CENTER;
        case SPEAKER_LOW_FREQUENCY:         return MA_CHANNEL_LFE;
        case SPEAKER_BACK_LEFT:             return MA_CHANNEL_BACK_LEFT;
        case SPEAKER_BACK_RIGHT:            return MA_CHANNEL_BACK_RIGHT;
        case SPEAKER_FRONT_LEFT_OF_CENTER:  return MA_CHANNEL_FRONT_LEFT_CENTER;
        case SPEAKER_FRONT_RIGHT_OF_CENTER: return MA_CHANNEL_FRONT_RIGHT_CENTER;
        case SPEAKER_BACK_CENTER:           return MA_CHANNEL_BACK_CENTER;
        case SPEAKER_SIDE_LEFT:             return MA_CHANNEL_SIDE_LEFT;
        case SPEAKER_SIDE_RIGHT:            return MA_CHANNEL_SIDE_RIGHT;
        case SPEAKER_TOP_CENTER:            return MA_CHANNEL_TOP_CENTER;
        case SPEAKER_TOP_FRONT_LEFT:        return MA_CHANNEL_TOP_FRONT_LEFT;
        case SPEAKER_TOP_FRONT_CENTER:      return MA_CHANNEL_TOP_FRONT_CENTER;
        case SPEAKER_TOP_FRONT_RIGHT:       return MA_CHANNEL_TOP_FRONT_RIGHT;
        case SPEAKER_TOP_BACK_LEFT:         return MA_CHANNEL_TOP_BACK_LEFT;
        case SPEAKER_TOP_BACK_CENTER:       return MA_CHANNEL_TOP_BACK_CENTER;
        case SPEAKER_TOP_BACK_RIGHT:        return MA_CHANNEL_TOP_BACK_RIGHT;
        default: return 0;
    }
}

/* Converts an individual miniaudio channel identifier (MA_CHANNEL_FRONT_LEFT, etc.) to Win32-style. */
static DWORD ma_channel_id_to_win32(DWORD id)
{
    switch (id)
    {
        case MA_CHANNEL_MONO:               return SPEAKER_FRONT_CENTER;
        case MA_CHANNEL_FRONT_LEFT:         return SPEAKER_FRONT_LEFT;
        case MA_CHANNEL_FRONT_RIGHT:        return SPEAKER_FRONT_RIGHT;
        case MA_CHANNEL_FRONT_CENTER:       return SPEAKER_FRONT_CENTER;
        case MA_CHANNEL_LFE:                return SPEAKER_LOW_FREQUENCY;
        case MA_CHANNEL_BACK_LEFT:          return SPEAKER_BACK_LEFT;
        case MA_CHANNEL_BACK_RIGHT:         return SPEAKER_BACK_RIGHT;
        case MA_CHANNEL_FRONT_LEFT_CENTER:  return SPEAKER_FRONT_LEFT_OF_CENTER;
        case MA_CHANNEL_FRONT_RIGHT_CENTER: return SPEAKER_FRONT_RIGHT_OF_CENTER;
        case MA_CHANNEL_BACK_CENTER:        return SPEAKER_BACK_CENTER;
        case MA_CHANNEL_SIDE_LEFT:          return SPEAKER_SIDE_LEFT;
        case MA_CHANNEL_SIDE_RIGHT:         return SPEAKER_SIDE_RIGHT;
        case MA_CHANNEL_TOP_CENTER:         return SPEAKER_TOP_CENTER;
        case MA_CHANNEL_TOP_FRONT_LEFT:     return SPEAKER_TOP_FRONT_LEFT;
        case MA_CHANNEL_TOP_FRONT_CENTER:   return SPEAKER_TOP_FRONT_CENTER;
        case MA_CHANNEL_TOP_FRONT_RIGHT:    return SPEAKER_TOP_FRONT_RIGHT;
        case MA_CHANNEL_TOP_BACK_LEFT:      return SPEAKER_TOP_BACK_LEFT;
        case MA_CHANNEL_TOP_BACK_CENTER:    return SPEAKER_TOP_BACK_CENTER;
        case MA_CHANNEL_TOP_BACK_RIGHT:     return SPEAKER_TOP_BACK_RIGHT;
        default: return 0;
    }
}

/* Converts a channel mapping to a Win32-style channel mask. */
static DWORD ma_channel_map_to_channel_mask__win32(const ma_channel* pChannelMap, ma_uint32 channels)
{
    DWORD dwChannelMask = 0;
    ma_uint32 iChannel;

    for (iChannel = 0; iChannel < channels; ++iChannel) {
        dwChannelMask |= ma_channel_id_to_win32(pChannelMap[iChannel]);
    }

    return dwChannelMask;
}

/* Converts a Win32-style channel mask to a miniaudio channel map. */
static void ma_channel_mask_to_channel_map__win32(DWORD dwChannelMask, ma_uint32 channels, ma_channel* pChannelMap)
{
    /* If the channel mask is set to 0, just assume a default Win32 channel map. */
    if (dwChannelMask == 0) {
        ma_channel_map_init_standard(ma_standard_channel_map_microsoft, pChannelMap, channels, channels);
    } else {
        if (channels == 1 && (dwChannelMask & SPEAKER_FRONT_CENTER) != 0) {
            pChannelMap[0] = MA_CHANNEL_MONO;
        } else {
            /* Just iterate over each bit. */
            ma_uint32 iChannel = 0;
            ma_uint32 iBit;

            for (iBit = 0; iBit < 32 && iChannel < channels; ++iBit) {
                DWORD bitValue = (dwChannelMask & (1UL << iBit));
                if (bitValue != 0) {
                    /* The bit is set. */
                    pChannelMap[iChannel] = ma_channel_id_to_ma__win32(bitValue);
                    iChannel += 1;
                }
            }
        }
    }
}

#ifdef __cplusplus
static ma_bool32 ma_is_guid_equal(const void* a, const void* b)
{
    return IsEqualGUID(*(const GUID*)a, *(const GUID*)b);
}
#else
#define ma_is_guid_equal(a, b) IsEqualGUID((const GUID*)a, (const GUID*)b)
#endif

static MA_INLINE ma_bool32 ma_is_guid_null(const void* guid)
{
    static GUID nullguid = {0x00000000, 0x0000, 0x0000, {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00}};
    return ma_is_guid_equal(guid, &nullguid);
}

static ma_format ma_format_from_WAVEFORMATEX(const MA_WAVEFORMATEX* pWF)
{
    MA_ASSERT(pWF != NULL);

    if (pWF->wFormatTag == WAVE_FORMAT_EXTENSIBLE) {
        const MA_WAVEFORMATEXTENSIBLE* pWFEX = (const MA_WAVEFORMATEXTENSIBLE*)pWF;
        if (ma_is_guid_equal(&pWFEX->SubFormat, &MA_GUID_KSDATAFORMAT_SUBTYPE_PCM)) {
            if (pWFEX->Samples.wValidBitsPerSample == 32) {
                return ma_format_s32;
            }
            if (pWFEX->Samples.wValidBitsPerSample == 24) {
                if (pWFEX->wBitsPerSample == 32) {
                    return ma_format_s32;
                }
                if (pWFEX->wBitsPerSample == 24) {
                    return ma_format_s24;
                }
            }
            if (pWFEX->Samples.wValidBitsPerSample == 16) {
                return ma_format_s16;
            }
            if (pWFEX->Samples.wValidBitsPerSample == 8) {
                return ma_format_u8;
            }
        }
        if (ma_is_guid_equal(&pWFEX->SubFormat, &MA_GUID_KSDATAFORMAT_SUBTYPE_IEEE_FLOAT)) {
            if (pWFEX->Samples.wValidBitsPerSample == 32) {
                return ma_format_f32;
            }
            /*
            if (pWFEX->Samples.wValidBitsPerSample == 64) {
                return ma_format_f64;
            }
            */
        }
    } else {
        if (pWF->wFormatTag == WAVE_FORMAT_PCM) {
            if (pWF->wBitsPerSample == 32) {
                return ma_format_s32;
            }
            if (pWF->wBitsPerSample == 24) {
                return ma_format_s24;
            }
            if (pWF->wBitsPerSample == 16) {
                return ma_format_s16;
            }
            if (pWF->wBitsPerSample == 8) {
                return ma_format_u8;
            }
        }
        if (pWF->wFormatTag == WAVE_FORMAT_IEEE_FLOAT) {
            if (pWF->wBitsPerSample == 32) {
                return ma_format_f32;
            }
            if (pWF->wBitsPerSample == 64) {
                /*return ma_format_f64;*/
            }
        }
    }

    return ma_format_unknown;
}
#endif


/*******************************************************************************

WASAPI Backend

*******************************************************************************/
#ifdef MA_HAS_WASAPI
#if 0
#if defined(_MSC_VER)
    #pragma warning(push)
    #pragma warning(disable:4091)   /* 'typedef ': ignored on left of '' when no variable is declared */
#endif
#include <audioclient.h>
#include <mmdeviceapi.h>
#if defined(_MSC_VER)
    #pragma warning(pop)
#endif
#endif  /* 0 */

static ma_result ma_device_reroute__wasapi(ma_device* pDevice, ma_device_type deviceType);

/* Some compilers don't define VerifyVersionInfoW. Need to write this ourselves. */
#define MA_WIN32_WINNT_VISTA    0x0600
#define MA_VER_MINORVERSION     0x01
#define MA_VER_MAJORVERSION     0x02
#define MA_VER_SERVICEPACKMAJOR 0x20
#define MA_VER_GREATER_EQUAL    0x03

typedef struct  {
    DWORD dwOSVersionInfoSize;
    DWORD dwMajorVersion;
    DWORD dwMinorVersion;
    DWORD dwBuildNumber;
    DWORD dwPlatformId;
    WCHAR szCSDVersion[128];
    WORD  wServicePackMajor;
    WORD  wServicePackMinor;
    WORD  wSuiteMask;
    BYTE  wProductType;
    BYTE  wReserved;
} ma_OSVERSIONINFOEXW;

typedef BOOL      (WINAPI * ma_PFNVerifyVersionInfoW) (ma_OSVERSIONINFOEXW* lpVersionInfo, DWORD dwTypeMask, DWORDLONG dwlConditionMask);
typedef ULONGLONG (WINAPI * ma_PFNVerSetConditionMask)(ULONGLONG dwlConditionMask, DWORD dwTypeBitMask, BYTE dwConditionMask);


#ifndef PROPERTYKEY_DEFINED
#define PROPERTYKEY_DEFINED
#ifndef __WATCOMC__
typedef struct
{
    GUID fmtid;
    DWORD pid;
} PROPERTYKEY;
#endif
#endif

/* Some compilers don't define PropVariantInit(). We just do this ourselves since it's just a memset(). */
static MA_INLINE void ma_PropVariantInit(MA_PROPVARIANT* pProp)
{
    MA_ZERO_OBJECT(pProp);
}


static const PROPERTYKEY MA_PKEY_Device_FriendlyName             = {{0xA45C254E, 0xDF1C, 0x4EFD, {0x80, 0x20, 0x67, 0xD1, 0x46, 0xA8, 0x50, 0xE0}}, 14};
static const PROPERTYKEY MA_PKEY_AudioEngine_DeviceFormat        = {{0xF19F064D, 0x82C,  0x4E27, {0xBC, 0x73, 0x68, 0x82, 0xA1, 0xBB, 0x8E, 0x4C}},  0};

static const IID MA_IID_IUnknown                                 = {0x00000000, 0x0000, 0x0000, {0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46}}; /* 00000000-0000-0000-C000-000000000046 */
#if !defined(MA_WIN32_DESKTOP) && !defined(MA_WIN32_GDK)
static const IID MA_IID_IAgileObject                             = {0x94EA2B94, 0xE9CC, 0x49E0, {0xC0, 0xFF, 0xEE, 0x64, 0xCA, 0x8F, 0x5B, 0x90}}; /* 94EA2B94-E9CC-49E0-C0FF-EE64CA8F5B90 */
#endif

static const IID MA_IID_IAudioClient                             = {0x1CB9AD4C, 0xDBFA, 0x4C32, {0xB1, 0x78, 0xC2, 0xF5, 0x68, 0xA7, 0x03, 0xB2}}; /* 1CB9AD4C-DBFA-4C32-B178-C2F568A703B2 = __uuidof(IAudioClient) */
static const IID MA_IID_IAudioClient2                            = {0x726778CD, 0xF60A, 0x4EDA, {0x82, 0xDE, 0xE4, 0x76, 0x10, 0xCD, 0x78, 0xAA}}; /* 726778CD-F60A-4EDA-82DE-E47610CD78AA = __uuidof(IAudioClient2) */
static const IID MA_IID_IAudioClient3                            = {0x7ED4EE07, 0x8E67, 0x4CD4, {0x8C, 0x1A, 0x2B, 0x7A, 0x59, 0x87, 0xAD, 0x42}}; /* 7ED4EE07-8E67-4CD4-8C1A-2B7A5987AD42 = __uuidof(IAudioClient3) */
static const IID MA_IID_IAudioRenderClient                       = {0xF294ACFC, 0x3146, 0x4483, {0xA7, 0xBF, 0xAD, 0xDC, 0xA7, 0xC2, 0x60, 0xE2}}; /* F294ACFC-3146-4483-A7BF-ADDCA7C260E2 = __uuidof(IAudioRenderClient) */
static const IID MA_IID_IAudioCaptureClient                      = {0xC8ADBD64, 0xE71E, 0x48A0, {0xA4, 0xDE, 0x18, 0x5C, 0x39, 0x5C, 0xD3, 0x17}}; /* C8ADBD64-E71E-48A0-A4DE-185C395CD317 = __uuidof(IAudioCaptureClient) */
static const IID MA_IID_IMMNotificationClient                    = {0x7991EEC9, 0x7E89, 0x4D85, {0x83, 0x90, 0x6C, 0x70, 0x3C, 0xEC, 0x60, 0xC0}}; /* 7991EEC9-7E89-4D85-8390-6C703CEC60C0 = __uuidof(IMMNotificationClient) */
#if !defined(MA_WIN32_DESKTOP) && !defined(MA_WIN32_GDK)
static const IID MA_IID_DEVINTERFACE_AUDIO_RENDER                = {0xE6327CAD, 0xDCEC, 0x4949, {0xAE, 0x8A, 0x99, 0x1E, 0x97, 0x6A, 0x79, 0xD2}}; /* E6327CAD-DCEC-4949-AE8A-991E976A79D2 */
static const IID MA_IID_DEVINTERFACE_AUDIO_CAPTURE               = {0x2EEF81BE, 0x33FA, 0x4800, {0x96, 0x70, 0x1C, 0xD4, 0x74, 0x97, 0x2C, 0x3F}}; /* 2EEF81BE-33FA-4800-9670-1CD474972C3F */
static const IID MA_IID_IActivateAudioInterfaceCompletionHandler = {0x41D949AB, 0x9862, 0x444A, {0x80, 0xF6, 0xC2, 0x61, 0x33, 0x4D, 0xA5, 0xEB}}; /* 41D949AB-9862-444A-80F6-C261334DA5EB */
#endif

static const IID MA_CLSID_MMDeviceEnumerator                     = {0xBCDE0395, 0xE52F, 0x467C, {0x8E, 0x3D, 0xC4, 0x57, 0x92, 0x91, 0x69, 0x2E}}; /* BCDE0395-E52F-467C-8E3D-C4579291692E = __uuidof(MMDeviceEnumerator) */
static const IID MA_IID_IMMDeviceEnumerator                      = {0xA95664D2, 0x9614, 0x4F35, {0xA7, 0x46, 0xDE, 0x8D, 0xB6, 0x36, 0x17, 0xE6}}; /* A95664D2-9614-4F35-A746-DE8DB63617E6 = __uuidof(IMMDeviceEnumerator) */

#if defined(MA_WIN32_DESKTOP) || defined(MA_WIN32_GDK)
#define MA_MM_DEVICE_STATE_ACTIVE                          1
#define MA_MM_DEVICE_STATE_DISABLED                        2
#define MA_MM_DEVICE_STATE_NOTPRESENT                      4
#define MA_MM_DEVICE_STATE_UNPLUGGED                       8

typedef struct ma_IMMDeviceEnumerator                      ma_IMMDeviceEnumerator;
typedef struct ma_IMMDeviceCollection                      ma_IMMDeviceCollection;
typedef struct ma_IMMDevice                                ma_IMMDevice;
#else
typedef struct ma_IActivateAudioInterfaceCompletionHandler ma_IActivateAudioInterfaceCompletionHandler;
typedef struct ma_IActivateAudioInterfaceAsyncOperation    ma_IActivateAudioInterfaceAsyncOperation;
#endif
typedef struct ma_IPropertyStore                           ma_IPropertyStore;
typedef struct ma_IAudioClient                             ma_IAudioClient;
typedef struct ma_IAudioClient2                            ma_IAudioClient2;
typedef struct ma_IAudioClient3                            ma_IAudioClient3;
typedef struct ma_IAudioRenderClient                       ma_IAudioRenderClient;
typedef struct ma_IAudioCaptureClient                      ma_IAudioCaptureClient;

typedef ma_int64                                           MA_REFERENCE_TIME;

#define MA_AUDCLNT_STREAMFLAGS_CROSSPROCESS                0x00010000
#define MA_AUDCLNT_STREAMFLAGS_LOOPBACK                    0x00020000
#define MA_AUDCLNT_STREAMFLAGS_EVENTCALLBACK               0x00040000
#define MA_AUDCLNT_STREAMFLAGS_NOPERSIST                   0x00080000
#define MA_AUDCLNT_STREAMFLAGS_RATEADJUST                  0x00100000
#define MA_AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY         0x08000000
#define MA_AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM              0x80000000
#define MA_AUDCLNT_SESSIONFLAGS_EXPIREWHENUNOWNED          0x10000000
#define MA_AUDCLNT_SESSIONFLAGS_DISPLAY_HIDE               0x20000000
#define MA_AUDCLNT_SESSIONFLAGS_DISPLAY_HIDEWHENEXPIRED    0x40000000

/* Buffer flags. */
#define MA_AUDCLNT_BUFFERFLAGS_DATA_DISCONTINUITY          1
#define MA_AUDCLNT_BUFFERFLAGS_SILENT                      2
#define MA_AUDCLNT_BUFFERFLAGS_TIMESTAMP_ERROR             4

typedef enum
{
    ma_eRender  = 0,
    ma_eCapture = 1,
    ma_eAll     = 2
} ma_EDataFlow;

typedef enum
{
    ma_eConsole        = 0,
    ma_eMultimedia     = 1,
    ma_eCommunications = 2
} ma_ERole;

typedef enum
{
    MA_AUDCLNT_SHAREMODE_SHARED,
    MA_AUDCLNT_SHAREMODE_EXCLUSIVE
} MA_AUDCLNT_SHAREMODE;

typedef enum
{
    MA_AudioCategory_Other = 0  /* <-- miniaudio is only caring about Other. */
} MA_AUDIO_STREAM_CATEGORY;

typedef struct
{
    ma_uint32 cbSize;
    BOOL bIsOffload;
    MA_AUDIO_STREAM_CATEGORY eCategory;
} ma_AudioClientProperties;

/* IUnknown */
typedef struct
{
    /* IUnknown */
    HRESULT (STDMETHODCALLTYPE * QueryInterface)(ma_IUnknown* pThis, const IID* const riid, void** ppObject);
    ULONG   (STDMETHODCALLTYPE * AddRef)        (ma_IUnknown* pThis);
    ULONG   (STDMETHODCALLTYPE * Release)       (ma_IUnknown* pThis);
} ma_IUnknownVtbl;
struct ma_IUnknown
{
    ma_IUnknownVtbl* lpVtbl;
};
static MA_INLINE HRESULT ma_IUnknown_QueryInterface(ma_IUnknown* pThis, const IID* const riid, void** ppObject) { return pThis->lpVtbl->QueryInterface(pThis, riid, ppObject); }
static MA_INLINE ULONG   ma_IUnknown_AddRef(ma_IUnknown* pThis)                                                 { return pThis->lpVtbl->AddRef(pThis); }
static MA_INLINE ULONG   ma_IUnknown_Release(ma_IUnknown* pThis)                                                { return pThis->lpVtbl->Release(pThis); }

#if defined(MA_WIN32_DESKTOP) || defined(MA_WIN32_GDK)
    /* IMMNotificationClient */
    typedef struct
    {
        /* IUnknown */
        HRESULT (STDMETHODCALLTYPE * QueryInterface)(ma_IMMNotificationClient* pThis, const IID* const riid, void** ppObject);
        ULONG   (STDMETHODCALLTYPE * AddRef)        (ma_IMMNotificationClient* pThis);
        ULONG   (STDMETHODCALLTYPE * Release)       (ma_IMMNotificationClient* pThis);

        /* IMMNotificationClient */
        HRESULT (STDMETHODCALLTYPE * OnDeviceStateChanged)  (ma_IMMNotificationClient* pThis, const WCHAR* pDeviceID, DWORD dwNewState);
        HRESULT (STDMETHODCALLTYPE * OnDeviceAdded)         (ma_IMMNotificationClient* pThis, const WCHAR* pDeviceID);
        HRESULT (STDMETHODCALLTYPE * OnDeviceRemoved)       (ma_IMMNotificationClient* pThis, const WCHAR* pDeviceID);
        HRESULT (STDMETHODCALLTYPE * OnDefaultDeviceChanged)(ma_IMMNotificationClient* pThis, ma_EDataFlow dataFlow, ma_ERole role, const WCHAR* pDefaultDeviceID);
        HRESULT (STDMETHODCALLTYPE * OnPropertyValueChanged)(ma_IMMNotificationClient* pThis, const WCHAR* pDeviceID, const PROPERTYKEY key);
    } ma_IMMNotificationClientVtbl;

    /* IMMDeviceEnumerator */
    typedef struct
    {
        /* IUnknown */
        HRESULT (STDMETHODCALLTYPE * QueryInterface)(ma_IMMDeviceEnumerator* pThis, const IID* const riid, void** ppObject);
        ULONG   (STDMETHODCALLTYPE * AddRef)        (ma_IMMDeviceEnumerator* pThis);
        ULONG   (STDMETHODCALLTYPE * Release)       (ma_IMMDeviceEnumerator* pThis);

        /* IMMDeviceEnumerator */
        HRESULT (STDMETHODCALLTYPE * EnumAudioEndpoints)                    (ma_IMMDeviceEnumerator* pThis, ma_EDataFlow dataFlow, DWORD dwStateMask, ma_IMMDeviceCollection** ppDevices);
        HRESULT (STDMETHODCALLTYPE * GetDefaultAudioEndpoint)               (ma_IMMDeviceEnumerator* pThis, ma_EDataFlow dataFlow, ma_ERole role, ma_IMMDevice** ppEndpoint);
        HRESULT (STDMETHODCALLTYPE * GetDevice)                             (ma_IMMDeviceEnumerator* pThis, const WCHAR* pID, ma_IMMDevice** ppDevice);
        HRESULT (STDMETHODCALLTYPE * RegisterEndpointNotificationCallback)  (ma_IMMDeviceEnumerator* pThis, ma_IMMNotificationClient* pClient);
        HRESULT (STDMETHODCALLTYPE * UnregisterEndpointNotificationCallback)(ma_IMMDeviceEnumerator* pThis, ma_IMMNotificationClient* pClient);
    } ma_IMMDeviceEnumeratorVtbl;
    struct ma_IMMDeviceEnumerator
    {
        ma_IMMDeviceEnumeratorVtbl* lpVtbl;
    };
    static MA_INLINE HRESULT ma_IMMDeviceEnumerator_QueryInterface(ma_IMMDeviceEnumerator* pThis, const IID* const riid, void** ppObject) { return pThis->lpVtbl->QueryInterface(pThis, riid, ppObject); }
    static MA_INLINE ULONG   ma_IMMDeviceEnumerator_AddRef(ma_IMMDeviceEnumerator* pThis)                                                 { return pThis->lpVtbl->AddRef(pThis); }
    static MA_INLINE ULONG   ma_IMMDeviceEnumerator_Release(ma_IMMDeviceEnumerator* pThis)                                                { return pThis->lpVtbl->Release(pThis); }
    static MA_INLINE HRESULT ma_IMMDeviceEnumerator_EnumAudioEndpoints(ma_IMMDeviceEnumerator* pThis, ma_EDataFlow dataFlow, DWORD dwStateMask, ma_IMMDeviceCollection** ppDevices) { return pThis->lpVtbl->EnumAudioEndpoints(pThis, dataFlow, dwStateMask, ppDevices); }
    static MA_INLINE HRESULT ma_IMMDeviceEnumerator_GetDefaultAudioEndpoint(ma_IMMDeviceEnumerator* pThis, ma_EDataFlow dataFlow, ma_ERole role, ma_IMMDevice** ppEndpoint) { return pThis->lpVtbl->GetDefaultAudioEndpoint(pThis, dataFlow, role, ppEndpoint); }
    static MA_INLINE HRESULT ma_IMMDeviceEnumerator_GetDevice(ma_IMMDeviceEnumerator* pThis, const WCHAR* pID, ma_IMMDevice** ppDevice) { return pThis->lpVtbl->GetDevice(pThis, pID, ppDevice); }
    static MA_INLINE HRESULT ma_IMMDeviceEnumerator_RegisterEndpointNotificationCallback(ma_IMMDeviceEnumerator* pThis, ma_IMMNotificationClient* pClient) { return pThis->lpVtbl->RegisterEndpointNotificationCallback(pThis, pClient); }
    static MA_INLINE HRESULT ma_IMMDeviceEnumerator_UnregisterEndpointNotificationCallback(ma_IMMDeviceEnumerator* pThis, ma_IMMNotificationClient* pClient) { return pThis->lpVtbl->UnregisterEndpointNotificationCallback(pThis, pClient); }


    /* IMMDeviceCollection */
    typedef struct
    {
        /* IUnknown */
        HRESULT (STDMETHODCALLTYPE * QueryInterface)(ma_IMMDeviceCollection* pThis, const IID* const riid, void** ppObject);
        ULONG   (STDMETHODCALLTYPE * AddRef)        (ma_IMMDeviceCollection* pThis);
        ULONG   (STDMETHODCALLTYPE * Release)       (ma_IMMDeviceCollection* pThis);

        /* IMMDeviceCollection */
        HRESULT (STDMETHODCALLTYPE * GetCount)(ma_IMMDeviceCollection* pThis, UINT* pDevices);
        HRESULT (STDMETHODCALLTYPE * Item)    (ma_IMMDeviceCollection* pThis, UINT nDevice, ma_IMMDevice** ppDevice);
    } ma_IMMDeviceCollectionVtbl;
    struct ma_IMMDeviceCollection
    {
        ma_IMMDeviceCollectionVtbl* lpVtbl;
    };
    static MA_INLINE HRESULT ma_IMMDeviceCollection_QueryInterface(ma_IMMDeviceCollection* pThis, const IID* const riid, void** ppObject) { return pThis->lpVtbl->QueryInterface(pThis, riid, ppObject); }
    static MA_INLINE ULONG   ma_IMMDeviceCollection_AddRef(ma_IMMDeviceCollection* pThis)                                                 { return pThis->lpVtbl->AddRef(pThis); }
    static MA_INLINE ULONG   ma_IMMDeviceCollection_Release(ma_IMMDeviceCollection* pThis)                                                { return pThis->lpVtbl->Release(pThis); }
    static MA_INLINE HRESULT ma_IMMDeviceCollection_GetCount(ma_IMMDeviceCollection* pThis, UINT* pDevices)                               { return pThis->lpVtbl->GetCount(pThis, pDevices); }
    static MA_INLINE HRESULT ma_IMMDeviceCollection_Item(ma_IMMDeviceCollection* pThis, UINT nDevice, ma_IMMDevice** ppDevice)            { return pThis->lpVtbl->Item(pThis, nDevice, ppDevice); }


    /* IMMDevice */
    typedef struct
    {
        /* IUnknown */
        HRESULT (STDMETHODCALLTYPE * QueryInterface)(ma_IMMDevice* pThis, const IID* const riid, void** ppObject);
        ULONG   (STDMETHODCALLTYPE * AddRef)        (ma_IMMDevice* pThis);
        ULONG   (STDMETHODCALLTYPE * Release)       (ma_IMMDevice* pThis);

        /* IMMDevice */
        HRESULT (STDMETHODCALLTYPE * Activate)         (ma_IMMDevice* pThis, const IID* const iid, DWORD dwClsCtx, MA_PROPVARIANT* pActivationParams, void** ppInterface);
        HRESULT (STDMETHODCALLTYPE * OpenPropertyStore)(ma_IMMDevice* pThis, DWORD stgmAccess, ma_IPropertyStore** ppProperties);
        HRESULT (STDMETHODCALLTYPE * GetId)            (ma_IMMDevice* pThis, WCHAR** pID);
        HRESULT (STDMETHODCALLTYPE * GetState)         (ma_IMMDevice* pThis, DWORD *pState);
    } ma_IMMDeviceVtbl;
    struct ma_IMMDevice
    {
        ma_IMMDeviceVtbl* lpVtbl;
    };
    static MA_INLINE HRESULT ma_IMMDevice_QueryInterface(ma_IMMDevice* pThis, const IID* const riid, void** ppObject) { return pThis->lpVtbl->QueryInterface(pThis, riid, ppObject); }
    static MA_INLINE ULONG   ma_IMMDevice_AddRef(ma_IMMDevice* pThis)                                                 { return pThis->lpVtbl->AddRef(pThis); }
    static MA_INLINE ULONG   ma_IMMDevice_Release(ma_IMMDevice* pThis)                                                { return pThis->lpVtbl->Release(pThis); }
    static MA_INLINE HRESULT ma_IMMDevice_Activate(ma_IMMDevice* pThis, const IID* const iid, DWORD dwClsCtx, MA_PROPVARIANT* pActivationParams, void** ppInterface) { return pThis->lpVtbl->Activate(pThis, iid, dwClsCtx, pActivationParams, ppInterface); }
    static MA_INLINE HRESULT ma_IMMDevice_OpenPropertyStore(ma_IMMDevice* pThis, DWORD stgmAccess, ma_IPropertyStore** ppProperties) { return pThis->lpVtbl->OpenPropertyStore(pThis, stgmAccess, ppProperties); }
    static MA_INLINE HRESULT ma_IMMDevice_GetId(ma_IMMDevice* pThis, WCHAR** pID)                                     { return pThis->lpVtbl->GetId(pThis, pID); }
    static MA_INLINE HRESULT ma_IMMDevice_GetState(ma_IMMDevice* pThis, DWORD *pState)                                { return pThis->lpVtbl->GetState(pThis, pState); }
#else
    /* IActivateAudioInterfaceAsyncOperation */
    typedef struct
    {
        /* IUnknown */
        HRESULT (STDMETHODCALLTYPE * QueryInterface)(ma_IActivateAudioInterfaceAsyncOperation* pThis, const IID* const riid, void** ppObject);
        ULONG   (STDMETHODCALLTYPE * AddRef)        (ma_IActivateAudioInterfaceAsyncOperation* pThis);
        ULONG   (STDMETHODCALLTYPE * Release)       (ma_IActivateAudioInterfaceAsyncOperation* pThis);

        /* IActivateAudioInterfaceAsyncOperation */
        HRESULT (STDMETHODCALLTYPE * GetActivateResult)(ma_IActivateAudioInterfaceAsyncOperation* pThis, HRESULT *pActivateResult, ma_IUnknown** ppActivatedInterface);
    } ma_IActivateAudioInterfaceAsyncOperationVtbl;
    struct ma_IActivateAudioInterfaceAsyncOperation
    {
        ma_IActivateAudioInterfaceAsyncOperationVtbl* lpVtbl;
    };
    static MA_INLINE HRESULT ma_IActivateAudioInterfaceAsyncOperation_QueryInterface(ma_IActivateAudioInterfaceAsyncOperation* pThis, const IID* const riid, void** ppObject) { return pThis->lpVtbl->QueryInterface(pThis, riid, ppObject); }
    static MA_INLINE ULONG   ma_IActivateAudioInterfaceAsyncOperation_AddRef(ma_IActivateAudioInterfaceAsyncOperation* pThis)                                                 { return pThis->lpVtbl->AddRef(pThis); }
    static MA_INLINE ULONG   ma_IActivateAudioInterfaceAsyncOperation_Release(ma_IActivateAudioInterfaceAsyncOperation* pThis)                                                { return pThis->lpVtbl->Release(pThis); }
    static MA_INLINE HRESULT ma_IActivateAudioInterfaceAsyncOperation_GetActivateResult(ma_IActivateAudioInterfaceAsyncOperation* pThis, HRESULT *pActivateResult, ma_IUnknown** ppActivatedInterface) { return pThis->lpVtbl->GetActivateResult(pThis, pActivateResult, ppActivatedInterface); }
#endif

/* IPropertyStore */
typedef struct
{
    /* IUnknown */
    HRESULT (STDMETHODCALLTYPE * QueryInterface)(ma_IPropertyStore* pThis, const IID* const riid, void** ppObject);
    ULONG   (STDMETHODCALLTYPE * AddRef)        (ma_IPropertyStore* pThis);
    ULONG   (STDMETHODCALLTYPE * Release)       (ma_IPropertyStore* pThis);

    /* IPropertyStore */
    HRESULT (STDMETHODCALLTYPE * GetCount)(ma_IPropertyStore* pThis, DWORD* pPropCount);
    HRESULT (STDMETHODCALLTYPE * GetAt)   (ma_IPropertyStore* pThis, DWORD propIndex, PROPERTYKEY* pPropKey);
    HRESULT (STDMETHODCALLTYPE * GetValue)(ma_IPropertyStore* pThis, const PROPERTYKEY* const pKey, MA_PROPVARIANT* pPropVar);
    HRESULT (STDMETHODCALLTYPE * SetValue)(ma_IPropertyStore* pThis, const PROPERTYKEY* const pKey, const MA_PROPVARIANT* const pPropVar);
    HRESULT (STDMETHODCALLTYPE * Commit)  (ma_IPropertyStore* pThis);
} ma_IPropertyStoreVtbl;
struct ma_IPropertyStore
{
    ma_IPropertyStoreVtbl* lpVtbl;
};
static MA_INLINE HRESULT ma_IPropertyStore_QueryInterface(ma_IPropertyStore* pThis, const IID* const riid, void** ppObject) { return pThis->lpVtbl->QueryInterface(pThis, riid, ppObject); }
static MA_INLINE ULONG   ma_IPropertyStore_AddRef(ma_IPropertyStore* pThis)                                                 { return pThis->lpVtbl->AddRef(pThis); }
static MA_INLINE ULONG   ma_IPropertyStore_Release(ma_IPropertyStore* pThis)                                                { return pThis->lpVtbl->Release(pThis); }
static MA_INLINE HRESULT ma_IPropertyStore_GetCount(ma_IPropertyStore* pThis, DWORD* pPropCount)                            { return pThis->lpVtbl->GetCount(pThis, pPropCount); }
static MA_INLINE HRESULT ma_IPropertyStore_GetAt(ma_IPropertyStore* pThis, DWORD propIndex, PROPERTYKEY* pPropKey)          { return pThis->lpVtbl->GetAt(pThis, propIndex, pPropKey); }
static MA_INLINE HRESULT ma_IPropertyStore_GetValue(ma_IPropertyStore* pThis, const PROPERTYKEY* const pKey, MA_PROPVARIANT* pPropVar) { return pThis->lpVtbl->GetValue(pThis, pKey, pPropVar); }
static MA_INLINE HRESULT ma_IPropertyStore_SetValue(ma_IPropertyStore* pThis, const PROPERTYKEY* const pKey, const MA_PROPVARIANT* const pPropVar) { return pThis->lpVtbl->SetValue(pThis, pKey, pPropVar); }
static MA_INLINE HRESULT ma_IPropertyStore_Commit(ma_IPropertyStore* pThis)                                                 { return pThis->lpVtbl->Commit(pThis); }


/* IAudioClient */
typedef struct
{
    /* IUnknown */
    HRESULT (STDMETHODCALLTYPE * QueryInterface)(ma_IAudioClient* pThis, const IID* const riid, void** ppObject);
    ULONG   (STDMETHODCALLTYPE * AddRef)        (ma_IAudioClient* pThis);
    ULONG   (STDMETHODCALLTYPE * Release)       (ma_IAudioClient* pThis);

    /* IAudioClient */
    HRESULT (STDMETHODCALLTYPE * Initialize)       (ma_IAudioClient* pThis, MA_AUDCLNT_SHAREMODE shareMode, DWORD streamFlags, MA_REFERENCE_TIME bufferDuration, MA_REFERENCE_TIME periodicity, const MA_WAVEFORMATEX* pFormat, const GUID* pAudioSessionGuid);
    HRESULT (STDMETHODCALLTYPE * GetBufferSize)    (ma_IAudioClient* pThis, ma_uint32* pNumBufferFrames);
    HRESULT (STDMETHODCALLTYPE * GetStreamLatency) (ma_IAudioClient* pThis, MA_REFERENCE_TIME* pLatency);
    HRESULT (STDMETHODCALLTYPE * GetCurrentPadding)(ma_IAudioClient* pThis, ma_uint32* pNumPaddingFrames);
    HRESULT (STDMETHODCALLTYPE * IsFormatSupported)(ma_IAudioClient* pThis, MA_AUDCLNT_SHAREMODE shareMode, const MA_WAVEFORMATEX* pFormat, MA_WAVEFORMATEX** ppClosestMatch);
    HRESULT (STDMETHODCALLTYPE * GetMixFormat)     (ma_IAudioClient* pThis, MA_WAVEFORMATEX** ppDeviceFormat);
    HRESULT (STDMETHODCALLTYPE * GetDevicePeriod)  (ma_IAudioClient* pThis, MA_REFERENCE_TIME* pDefaultDevicePeriod, MA_REFERENCE_TIME* pMinimumDevicePeriod);
    HRESULT (STDMETHODCALLTYPE * Start)            (ma_IAudioClient* pThis);
    HRESULT (STDMETHODCALLTYPE * Stop)             (ma_IAudioClient* pThis);
    HRESULT (STDMETHODCALLTYPE * Reset)            (ma_IAudioClient* pThis);
    HRESULT (STDMETHODCALLTYPE * SetEventHandle)   (ma_IAudioClient* pThis, HANDLE eventHandle);
    HRESULT (STDMETHODCALLTYPE * GetService)       (ma_IAudioClient* pThis, const IID* const riid, void** pp);
} ma_IAudioClientVtbl;
struct ma_IAudioClient
{
    ma_IAudioClientVtbl* lpVtbl;
};
static MA_INLINE HRESULT ma_IAudioClient_QueryInterface(ma_IAudioClient* pThis, const IID* const riid, void** ppObject)    { return pThis->lpVtbl->QueryInterface(pThis, riid, ppObject); }
static MA_INLINE ULONG   ma_IAudioClient_AddRef(ma_IAudioClient* pThis)                                                    { return pThis->lpVtbl->AddRef(pThis); }
static MA_INLINE ULONG   ma_IAudioClient_Release(ma_IAudioClient* pThis)                                                   { return pThis->lpVtbl->Release(pThis); }
static MA_INLINE HRESULT ma_IAudioClient_Initialize(ma_IAudioClient* pThis, MA_AUDCLNT_SHAREMODE shareMode, DWORD streamFlags, MA_REFERENCE_TIME bufferDuration, MA_REFERENCE_TIME periodicity, const MA_WAVEFORMATEX* pFormat, const GUID* pAudioSessionGuid) { return pThis->lpVtbl->Initialize(pThis, shareMode, streamFlags, bufferDuration, periodicity, pFormat, pAudioSessionGuid); }
static MA_INLINE HRESULT ma_IAudioClient_GetBufferSize(ma_IAudioClient* pThis, ma_uint32* pNumBufferFrames)                { return pThis->lpVtbl->GetBufferSize(pThis, pNumBufferFrames); }
static MA_INLINE HRESULT ma_IAudioClient_GetStreamLatency(ma_IAudioClient* pThis, MA_REFERENCE_TIME* pLatency)             { return pThis->lpVtbl->GetStreamLatency(pThis, pLatency); }
static MA_INLINE HRESULT ma_IAudioClient_GetCurrentPadding(ma_IAudioClient* pThis, ma_uint32* pNumPaddingFrames)           { return pThis->lpVtbl->GetCurrentPadding(pThis, pNumPaddingFrames); }
static MA_INLINE HRESULT ma_IAudioClient_IsFormatSupported(ma_IAudioClient* pThis, MA_AUDCLNT_SHAREMODE shareMode, const MA_WAVEFORMATEX* pFormat, MA_WAVEFORMATEX** ppClosestMatch) { return pThis->lpVtbl->IsFormatSupported(pThis, shareMode, pFormat, ppClosestMatch); }
static MA_INLINE HRESULT ma_IAudioClient_GetMixFormat(ma_IAudioClient* pThis, MA_WAVEFORMATEX** ppDeviceFormat)            { return pThis->lpVtbl->GetMixFormat(pThis, ppDeviceFormat); }
static MA_INLINE HRESULT ma_IAudioClient_GetDevicePeriod(ma_IAudioClient* pThis, MA_REFERENCE_TIME* pDefaultDevicePeriod, MA_REFERENCE_TIME* pMinimumDevicePeriod) { return pThis->lpVtbl->GetDevicePeriod(pThis, pDefaultDevicePeriod, pMinimumDevicePeriod); }
static MA_INLINE HRESULT ma_IAudioClient_Start(ma_IAudioClient* pThis)                                                     { return pThis->lpVtbl->Start(pThis); }
static MA_INLINE HRESULT ma_IAudioClient_Stop(ma_IAudioClient* pThis)                                                      { return pThis->lpVtbl->Stop(pThis); }
static MA_INLINE HRESULT ma_IAudioClient_Reset(ma_IAudioClient* pThis)                                                     { return pThis->lpVtbl->Reset(pThis); }
static MA_INLINE HRESULT ma_IAudioClient_SetEventHandle(ma_IAudioClient* pThis, HANDLE eventHandle)                        { return pThis->lpVtbl->SetEventHandle(pThis, eventHandle); }
static MA_INLINE HRESULT ma_IAudioClient_GetService(ma_IAudioClient* pThis, const IID* const riid, void** pp)              { return pThis->lpVtbl->GetService(pThis, riid, pp); }

/* IAudioClient2 */
typedef struct
{
    /* IUnknown */
    HRESULT (STDMETHODCALLTYPE * QueryInterface)(ma_IAudioClient2* pThis, const IID* const riid, void** ppObject);
    ULONG   (STDMETHODCALLTYPE * AddRef)        (ma_IAudioClient2* pThis);
    ULONG   (STDMETHODCALLTYPE * Release)       (ma_IAudioClient2* pThis);

    /* IAudioClient */
    HRESULT (STDMETHODCALLTYPE * Initialize)       (ma_IAudioClient2* pThis, MA_AUDCLNT_SHAREMODE shareMode, DWORD streamFlags, MA_REFERENCE_TIME bufferDuration, MA_REFERENCE_TIME periodicity, const MA_WAVEFORMATEX* pFormat, const GUID* pAudioSessionGuid);
    HRESULT (STDMETHODCALLTYPE * GetBufferSize)    (ma_IAudioClient2* pThis, ma_uint32* pNumBufferFrames);
    HRESULT (STDMETHODCALLTYPE * GetStreamLatency) (ma_IAudioClient2* pThis, MA_REFERENCE_TIME* pLatency);
    HRESULT (STDMETHODCALLTYPE * GetCurrentPadding)(ma_IAudioClient2* pThis, ma_uint32* pNumPaddingFrames);
    HRESULT (STDMETHODCALLTYPE * IsFormatSupported)(ma_IAudioClient2* pThis, MA_AUDCLNT_SHAREMODE shareMode, const MA_WAVEFORMATEX* pFormat, MA_WAVEFORMATEX** ppClosestMatch);
    HRESULT (STDMETHODCALLTYPE * GetMixFormat)     (ma_IAudioClient2* pThis, MA_WAVEFORMATEX** ppDeviceFormat);
    HRESULT (STDMETHODCALLTYPE * GetDevicePeriod)  (ma_IAudioClient2* pThis, MA_REFERENCE_TIME* pDefaultDevicePeriod, MA_REFERENCE_TIME* pMinimumDevicePeriod);
    HRESULT (STDMETHODCALLTYPE * Start)            (ma_IAudioClient2* pThis);
    HRESULT (STDMETHODCALLTYPE * Stop)             (ma_IAudioClient2* pThis);
    HRESULT (STDMETHODCALLTYPE * Reset)            (ma_IAudioClient2* pThis);
    HRESULT (STDMETHODCALLTYPE * SetEventHandle)   (ma_IAudioClient2* pThis, HANDLE eventHandle);
    HRESULT (STDMETHODCALLTYPE * GetService)       (ma_IAudioClient2* pThis, const IID* const riid, void** pp);

    /* IAudioClient2 */
    HRESULT (STDMETHODCALLTYPE * IsOffloadCapable)   (ma_IAudioClient2* pThis, MA_AUDIO_STREAM_CATEGORY category, BOOL* pOffloadCapable);
    HRESULT (STDMETHODCALLTYPE * SetClientProperties)(ma_IAudioClient2* pThis, const ma_AudioClientProperties* pProperties);
    HRESULT (STDMETHODCALLTYPE * GetBufferSizeLimits)(ma_IAudioClient2* pThis, const MA_WAVEFORMATEX* pFormat, BOOL eventDriven, MA_REFERENCE_TIME* pMinBufferDuration, MA_REFERENCE_TIME* pMaxBufferDuration);
} ma_IAudioClient2Vtbl;
struct ma_IAudioClient2
{
    ma_IAudioClient2Vtbl* lpVtbl;
};
static MA_INLINE HRESULT ma_IAudioClient2_QueryInterface(ma_IAudioClient2* pThis, const IID* const riid, void** ppObject)    { return pThis->lpVtbl->QueryInterface(pThis, riid, ppObject); }
static MA_INLINE ULONG   ma_IAudioClient2_AddRef(ma_IAudioClient2* pThis)                                                    { return pThis->lpVtbl->AddRef(pThis); }
static MA_INLINE ULONG   ma_IAudioClient2_Release(ma_IAudioClient2* pThis)                                                   { return pThis->lpVtbl->Release(pThis); }
static MA_INLINE HRESULT ma_IAudioClient2_Initialize(ma_IAudioClient2* pThis, MA_AUDCLNT_SHAREMODE shareMode, DWORD streamFlags, MA_REFERENCE_TIME bufferDuration, MA_REFERENCE_TIME periodicity, const MA_WAVEFORMATEX* pFormat, const GUID* pAudioSessionGuid) { return pThis->lpVtbl->Initialize(pThis, shareMode, streamFlags, bufferDuration, periodicity, pFormat, pAudioSessionGuid); }
static MA_INLINE HRESULT ma_IAudioClient2_GetBufferSize(ma_IAudioClient2* pThis, ma_uint32* pNumBufferFrames)                { return pThis->lpVtbl->GetBufferSize(pThis, pNumBufferFrames); }
static MA_INLINE HRESULT ma_IAudioClient2_GetStreamLatency(ma_IAudioClient2* pThis, MA_REFERENCE_TIME* pLatency)             { return pThis->lpVtbl->GetStreamLatency(pThis, pLatency); }
static MA_INLINE HRESULT ma_IAudioClient2_GetCurrentPadding(ma_IAudioClient2* pThis, ma_uint32* pNumPaddingFrames)           { return pThis->lpVtbl->GetCurrentPadding(pThis, pNumPaddingFrames); }
static MA_INLINE HRESULT ma_IAudioClient2_IsFormatSupported(ma_IAudioClient2* pThis, MA_AUDCLNT_SHAREMODE shareMode, const MA_WAVEFORMATEX* pFormat, MA_WAVEFORMATEX** ppClosestMatch) { return pThis->lpVtbl->IsFormatSupported(pThis, shareMode, pFormat, ppClosestMatch); }
static MA_INLINE HRESULT ma_IAudioClient2_GetMixFormat(ma_IAudioClient2* pThis, MA_WAVEFORMATEX** ppDeviceFormat)            { return pThis->lpVtbl->GetMixFormat(pThis, ppDeviceFormat); }
static MA_INLINE HRESULT ma_IAudioClient2_GetDevicePeriod(ma_IAudioClient2* pThis, MA_REFERENCE_TIME* pDefaultDevicePeriod, MA_REFERENCE_TIME* pMinimumDevicePeriod) { return pThis->lpVtbl->GetDevicePeriod(pThis, pDefaultDevicePeriod, pMinimumDevicePeriod); }
static MA_INLINE HRESULT ma_IAudioClient2_Start(ma_IAudioClient2* pThis)                                                     { return pThis->lpVtbl->Start(pThis); }
static MA_INLINE HRESULT ma_IAudioClient2_Stop(ma_IAudioClient2* pThis)                                                      { return pThis->lpVtbl->Stop(pThis); }
static MA_INLINE HRESULT ma_IAudioClient2_Reset(ma_IAudioClient2* pThis)                                                     { return pThis->lpVtbl->Reset(pThis); }
static MA_INLINE HRESULT ma_IAudioClient2_SetEventHandle(ma_IAudioClient2* pThis, HANDLE eventHandle)                        { return pThis->lpVtbl->SetEventHandle(pThis, eventHandle); }
static MA_INLINE HRESULT ma_IAudioClient2_GetService(ma_IAudioClient2* pThis, const IID* const riid, void** pp)              { return pThis->lpVtbl->GetService(pThis, riid, pp); }
static MA_INLINE HRESULT ma_IAudioClient2_IsOffloadCapable(ma_IAudioClient2* pThis, MA_AUDIO_STREAM_CATEGORY category, BOOL* pOffloadCapable) { return pThis->lpVtbl->IsOffloadCapable(pThis, category, pOffloadCapable); }
static MA_INLINE HRESULT ma_IAudioClient2_SetClientProperties(ma_IAudioClient2* pThis, const ma_AudioClientProperties* pProperties)           { return pThis->lpVtbl->SetClientProperties(pThis, pProperties); }
static MA_INLINE HRESULT ma_IAudioClient2_GetBufferSizeLimits(ma_IAudioClient2* pThis, const MA_WAVEFORMATEX* pFormat, BOOL eventDriven, MA_REFERENCE_TIME* pMinBufferDuration, MA_REFERENCE_TIME* pMaxBufferDuration) { return pThis->lpVtbl->GetBufferSizeLimits(pThis, pFormat, eventDriven, pMinBufferDuration, pMaxBufferDuration); }


/* IAudioClient3 */
typedef struct
{
    /* IUnknown */
    HRESULT (STDMETHODCALLTYPE * QueryInterface)(ma_IAudioClient3* pThis, const IID* const riid, void** ppObject);
    ULONG   (STDMETHODCALLTYPE * AddRef)        (ma_IAudioClient3* pThis);
    ULONG   (STDMETHODCALLTYPE * Release)       (ma_IAudioClient3* pThis);

    /* IAudioClient */
    HRESULT (STDMETHODCALLTYPE * Initialize)       (ma_IAudioClient3* pThis, MA_AUDCLNT_SHAREMODE shareMode, DWORD streamFlags, MA_REFERENCE_TIME bufferDuration, MA_REFERENCE_TIME periodicity, const MA_WAVEFORMATEX* pFormat, const GUID* pAudioSessionGuid);
    HRESULT (STDMETHODCALLTYPE * GetBufferSize)    (ma_IAudioClient3* pThis, ma_uint32* pNumBufferFrames);
    HRESULT (STDMETHODCALLTYPE * GetStreamLatency) (ma_IAudioClient3* pThis, MA_REFERENCE_TIME* pLatency);
    HRESULT (STDMETHODCALLTYPE * GetCurrentPadding)(ma_IAudioClient3* pThis, ma_uint32* pNumPaddingFrames);
    HRESULT (STDMETHODCALLTYPE * IsFormatSupported)(ma_IAudioClient3* pThis, MA_AUDCLNT_SHAREMODE shareMode, const MA_WAVEFORMATEX* pFormat, MA_WAVEFORMATEX** ppClosestMatch);
    HRESULT (STDMETHODCALLTYPE * GetMixFormat)     (ma_IAudioClient3* pThis, MA_WAVEFORMATEX** ppDeviceFormat);
    HRESULT (STDMETHODCALLTYPE * GetDevicePeriod)  (ma_IAudioClient3* pThis, MA_REFERENCE_TIME* pDefaultDevicePeriod, MA_REFERENCE_TIME* pMinimumDevicePeriod);
    HRESULT (STDMETHODCALLTYPE * Start)            (ma_IAudioClient3* pThis);
    HRESULT (STDMETHODCALLTYPE * Stop)             (ma_IAudioClient3* pThis);
    HRESULT (STDMETHODCALLTYPE * Reset)            (ma_IAudioClient3* pThis);
    HRESULT (STDMETHODCALLTYPE * SetEventHandle)   (ma_IAudioClient3* pThis, HANDLE eventHandle);
    HRESULT (STDMETHODCALLTYPE * GetService)       (ma_IAudioClient3* pThis, const IID* const riid, void** pp);

    /* IAudioClient2 */
    HRESULT (STDMETHODCALLTYPE * IsOffloadCapable)   (ma_IAudioClient3* pThis, MA_AUDIO_STREAM_CATEGORY category, BOOL* pOffloadCapable);
    HRESULT (STDMETHODCALLTYPE * SetClientProperties)(ma_IAudioClient3* pThis, const ma_AudioClientProperties* pProperties);
    HRESULT (STDMETHODCALLTYPE * GetBufferSizeLimits)(ma_IAudioClient3* pThis, const MA_WAVEFORMATEX* pFormat, BOOL eventDriven, MA_REFERENCE_TIME* pMinBufferDuration, MA_REFERENCE_TIME* pMaxBufferDuration);

    /* IAudioClient3 */
    HRESULT (STDMETHODCALLTYPE * GetSharedModeEnginePeriod)       (ma_IAudioClient3* pThis, const MA_WAVEFORMATEX* pFormat, ma_uint32* pDefaultPeriodInFrames, ma_uint32* pFundamentalPeriodInFrames, ma_uint32* pMinPeriodInFrames, ma_uint32* pMaxPeriodInFrames);
    HRESULT (STDMETHODCALLTYPE * GetCurrentSharedModeEnginePeriod)(ma_IAudioClient3* pThis, MA_WAVEFORMATEX** ppFormat, ma_uint32* pCurrentPeriodInFrames);
    HRESULT (STDMETHODCALLTYPE * InitializeSharedAudioStream)     (ma_IAudioClient3* pThis, DWORD streamFlags, ma_uint32 periodInFrames, const MA_WAVEFORMATEX* pFormat, const GUID* pAudioSessionGuid);
} ma_IAudioClient3Vtbl;
struct ma_IAudioClient3
{
    ma_IAudioClient3Vtbl* lpVtbl;
};
static MA_INLINE HRESULT ma_IAudioClient3_QueryInterface(ma_IAudioClient3* pThis, const IID* const riid, void** ppObject)    { return pThis->lpVtbl->QueryInterface(pThis, riid, ppObject); }
static MA_INLINE ULONG   ma_IAudioClient3_AddRef(ma_IAudioClient3* pThis)                                                    { return pThis->lpVtbl->AddRef(pThis); }
static MA_INLINE ULONG   ma_IAudioClient3_Release(ma_IAudioClient3* pThis)                                                   { return pThis->lpVtbl->Release(pThis); }
static MA_INLINE HRESULT ma_IAudioClient3_Initialize(ma_IAudioClient3* pThis, MA_AUDCLNT_SHAREMODE shareMode, DWORD streamFlags, MA_REFERENCE_TIME bufferDuration, MA_REFERENCE_TIME periodicity, const MA_WAVEFORMATEX* pFormat, const GUID* pAudioSessionGuid) { return pThis->lpVtbl->Initialize(pThis, shareMode, streamFlags, bufferDuration, periodicity, pFormat, pAudioSessionGuid); }
static MA_INLINE HRESULT ma_IAudioClient3_GetBufferSize(ma_IAudioClient3* pThis, ma_uint32* pNumBufferFrames)                { return pThis->lpVtbl->GetBufferSize(pThis, pNumBufferFrames); }
static MA_INLINE HRESULT ma_IAudioClient3_GetStreamLatency(ma_IAudioClient3* pThis, MA_REFERENCE_TIME* pLatency)             { return pThis->lpVtbl->GetStreamLatency(pThis, pLatency); }
static MA_INLINE HRESULT ma_IAudioClient3_GetCurrentPadding(ma_IAudioClient3* pThis, ma_uint32* pNumPaddingFrames)           { return pThis->lpVtbl->GetCurrentPadding(pThis, pNumPaddingFrames); }
static MA_INLINE HRESULT ma_IAudioClient3_IsFormatSupported(ma_IAudioClient3* pThis, MA_AUDCLNT_SHAREMODE shareMode, const MA_WAVEFORMATEX* pFormat, MA_WAVEFORMATEX** ppClosestMatch) { return pThis->lpVtbl->IsFormatSupported(pThis, shareMode, pFormat, ppClosestMatch); }
static MA_INLINE HRESULT ma_IAudioClient3_GetMixFormat(ma_IAudioClient3* pThis, MA_WAVEFORMATEX** ppDeviceFormat)               { return pThis->lpVtbl->GetMixFormat(pThis, ppDeviceFormat); }
static MA_INLINE HRESULT ma_IAudioClient3_GetDevicePeriod(ma_IAudioClient3* pThis, MA_REFERENCE_TIME* pDefaultDevicePeriod, MA_REFERENCE_TIME* pMinimumDevicePeriod) { return pThis->lpVtbl->GetDevicePeriod(pThis, pDefaultDevicePeriod, pMinimumDevicePeriod); }
static MA_INLINE HRESULT ma_IAudioClient3_Start(ma_IAudioClient3* pThis)                                                     { return pThis->lpVtbl->Start(pThis); }
static MA_INLINE HRESULT ma_IAudioClient3_Stop(ma_IAudioClient3* pThis)                                                      { return pThis->lpVtbl->Stop(pThis); }
static MA_INLINE HRESULT ma_IAudioClient3_Reset(ma_IAudioClient3* pThis)                                                     { return pThis->lpVtbl->Reset(pThis); }
static MA_INLINE HRESULT ma_IAudioClient3_SetEventHandle(ma_IAudioClient3* pThis, HANDLE eventHandle)                        { return pThis->lpVtbl->SetEventHandle(pThis, eventHandle); }
static MA_INLINE HRESULT ma_IAudioClient3_GetService(ma_IAudioClient3* pThis, const IID* const riid, void** pp)              { return pThis->lpVtbl->GetService(pThis, riid, pp); }
static MA_INLINE HRESULT ma_IAudioClient3_IsOffloadCapable(ma_IAudioClient3* pThis, MA_AUDIO_STREAM_CATEGORY category, BOOL* pOffloadCapable) { return pThis->lpVtbl->IsOffloadCapable(pThis, category, pOffloadCapable); }
static MA_INLINE HRESULT ma_IAudioClient3_SetClientProperties(ma_IAudioClient3* pThis, const ma_AudioClientProperties* pProperties)           { return pThis->lpVtbl->SetClientProperties(pThis, pProperties); }
static MA_INLINE HRESULT ma_IAudioClient3_GetBufferSizeLimits(ma_IAudioClient3* pThis, const MA_WAVEFORMATEX* pFormat, BOOL eventDriven, MA_REFERENCE_TIME* pMinBufferDuration, MA_REFERENCE_TIME* pMaxBufferDuration) { return pThis->lpVtbl->GetBufferSizeLimits(pThis, pFormat, eventDriven, pMinBufferDuration, pMaxBufferDuration); }
static MA_INLINE HRESULT ma_IAudioClient3_GetSharedModeEnginePeriod(ma_IAudioClient3* pThis, const MA_WAVEFORMATEX* pFormat, ma_uint32* pDefaultPeriodInFrames, ma_uint32* pFundamentalPeriodInFrames, ma_uint32* pMinPeriodInFrames, ma_uint32* pMaxPeriodInFrames) { return pThis->lpVtbl->GetSharedModeEnginePeriod(pThis, pFormat, pDefaultPeriodInFrames, pFundamentalPeriodInFrames, pMinPeriodInFrames, pMaxPeriodInFrames); }
static MA_INLINE HRESULT ma_IAudioClient3_GetCurrentSharedModeEnginePeriod(ma_IAudioClient3* pThis, MA_WAVEFORMATEX** ppFormat, ma_uint32* pCurrentPeriodInFrames) { return pThis->lpVtbl->GetCurrentSharedModeEnginePeriod(pThis, ppFormat, pCurrentPeriodInFrames); }
static MA_INLINE HRESULT ma_IAudioClient3_InitializeSharedAudioStream(ma_IAudioClient3* pThis, DWORD streamFlags, ma_uint32 periodInFrames, const MA_WAVEFORMATEX* pFormat, const GUID* pAudioSessionGUID) { return pThis->lpVtbl->InitializeSharedAudioStream(pThis, streamFlags, periodInFrames, pFormat, pAudioSessionGUID); }


/* IAudioRenderClient */
typedef struct
{
    /* IUnknown */
    HRESULT (STDMETHODCALLTYPE * QueryInterface)(ma_IAudioRenderClient* pThis, const IID* const riid, void** ppObject);
    ULONG   (STDMETHODCALLTYPE * AddRef)        (ma_IAudioRenderClient* pThis);
    ULONG   (STDMETHODCALLTYPE * Release)       (ma_IAudioRenderClient* pThis);

    /* IAudioRenderClient */
    HRESULT (STDMETHODCALLTYPE * GetBuffer)    (ma_IAudioRenderClient* pThis, ma_uint32 numFramesRequested, BYTE** ppData);
    HRESULT (STDMETHODCALLTYPE * ReleaseBuffer)(ma_IAudioRenderClient* pThis, ma_uint32 numFramesWritten, DWORD dwFlags);
} ma_IAudioRenderClientVtbl;
struct ma_IAudioRenderClient
{
    ma_IAudioRenderClientVtbl* lpVtbl;
};
static MA_INLINE HRESULT ma_IAudioRenderClient_QueryInterface(ma_IAudioRenderClient* pThis, const IID* const riid, void** ppObject)   { return pThis->lpVtbl->QueryInterface(pThis, riid, ppObject); }
static MA_INLINE ULONG   ma_IAudioRenderClient_AddRef(ma_IAudioRenderClient* pThis)                                                   { return pThis->lpVtbl->AddRef(pThis); }
static MA_INLINE ULONG   ma_IAudioRenderClient_Release(ma_IAudioRenderClient* pThis)                                                  { return pThis->lpVtbl->Release(pThis); }
static MA_INLINE HRESULT ma_IAudioRenderClient_GetBuffer(ma_IAudioRenderClient* pThis, ma_uint32 numFramesRequested, BYTE** ppData)   { return pThis->lpVtbl->GetBuffer(pThis, numFramesRequested, ppData); }
static MA_INLINE HRESULT ma_IAudioRenderClient_ReleaseBuffer(ma_IAudioRenderClient* pThis, ma_uint32 numFramesWritten, DWORD dwFlags) { return pThis->lpVtbl->ReleaseBuffer(pThis, numFramesWritten, dwFlags); }


/* IAudioCaptureClient */
typedef struct
{
    /* IUnknown */
    HRESULT (STDMETHODCALLTYPE * QueryInterface)(ma_IAudioCaptureClient* pThis, const IID* const riid, void** ppObject);
    ULONG   (STDMETHODCALLTYPE * AddRef)        (ma_IAudioCaptureClient* pThis);
    ULONG   (STDMETHODCALLTYPE * Release)       (ma_IAudioCaptureClient* pThis);

    /* IAudioRenderClient */
    HRESULT (STDMETHODCALLTYPE * GetBuffer)        (ma_IAudioCaptureClient* pThis, BYTE** ppData, ma_uint32* pNumFramesToRead, DWORD* pFlags, ma_uint64* pDevicePosition, ma_uint64* pQPCPosition);
    HRESULT (STDMETHODCALLTYPE * ReleaseBuffer)    (ma_IAudioCaptureClient* pThis, ma_uint32 numFramesRead);
    HRESULT (STDMETHODCALLTYPE * GetNextPacketSize)(ma_IAudioCaptureClient* pThis, ma_uint32* pNumFramesInNextPacket);
} ma_IAudioCaptureClientVtbl;
struct ma_IAudioCaptureClient
{
    ma_IAudioCaptureClientVtbl* lpVtbl;
};
static MA_INLINE HRESULT ma_IAudioCaptureClient_QueryInterface(ma_IAudioCaptureClient* pThis, const IID* const riid, void** ppObject) { return pThis->lpVtbl->QueryInterface(pThis, riid, ppObject); }
static MA_INLINE ULONG   ma_IAudioCaptureClient_AddRef(ma_IAudioCaptureClient* pThis)                                                 { return pThis->lpVtbl->AddRef(pThis); }
static MA_INLINE ULONG   ma_IAudioCaptureClient_Release(ma_IAudioCaptureClient* pThis)                                                { return pThis->lpVtbl->Release(pThis); }
static MA_INLINE HRESULT ma_IAudioCaptureClient_GetBuffer(ma_IAudioCaptureClient* pThis, BYTE** ppData, ma_uint32* pNumFramesToRead, DWORD* pFlags, ma_uint64* pDevicePosition, ma_uint64* pQPCPosition) { return pThis->lpVtbl->GetBuffer(pThis, ppData, pNumFramesToRead, pFlags, pDevicePosition, pQPCPosition); }
static MA_INLINE HRESULT ma_IAudioCaptureClient_ReleaseBuffer(ma_IAudioCaptureClient* pThis, ma_uint32 numFramesRead)                 { return pThis->lpVtbl->ReleaseBuffer(pThis, numFramesRead); }
static MA_INLINE HRESULT ma_IAudioCaptureClient_GetNextPacketSize(ma_IAudioCaptureClient* pThis, ma_uint32* pNumFramesInNextPacket)   { return pThis->lpVtbl->GetNextPacketSize(pThis, pNumFramesInNextPacket); }

#if defined(MA_WIN32_UWP)
/* mmdevapi Functions */
typedef HRESULT (WINAPI * MA_PFN_ActivateAudioInterfaceAsync)(const wchar_t* deviceInterfacePath, const IID* riid, MA_PROPVARIANT* activationParams, ma_IActivateAudioInterfaceCompletionHandler* completionHandler, ma_IActivateAudioInterfaceAsyncOperation** activationOperation);
#endif

/* Avrt Functions */
typedef HANDLE (WINAPI * MA_PFN_AvSetMmThreadCharacteristicsA)(const char* TaskName, DWORD* TaskIndex);
typedef BOOL   (WINAPI * MA_PFN_AvRevertMmThreadCharacteristics)(HANDLE AvrtHandle);

#if !defined(MA_WIN32_DESKTOP) && !defined(MA_WIN32_GDK)
typedef struct ma_completion_handler_uwp ma_completion_handler_uwp;

typedef struct
{
    /* IUnknown */
    HRESULT (STDMETHODCALLTYPE * QueryInterface)(ma_completion_handler_uwp* pThis, const IID* const riid, void** ppObject);
    ULONG   (STDMETHODCALLTYPE * AddRef)        (ma_completion_handler_uwp* pThis);
    ULONG   (STDMETHODCALLTYPE * Release)       (ma_completion_handler_uwp* pThis);

    /* IActivateAudioInterfaceCompletionHandler */
    HRESULT (STDMETHODCALLTYPE * ActivateCompleted)(ma_completion_handler_uwp* pThis, ma_IActivateAudioInterfaceAsyncOperation* pActivateOperation);
} ma_completion_handler_uwp_vtbl;
struct ma_completion_handler_uwp
{
    ma_completion_handler_uwp_vtbl* lpVtbl;
    MA_ATOMIC(4, ma_uint32) counter;
    HANDLE hEvent;
};

static HRESULT STDMETHODCALLTYPE ma_completion_handler_uwp_QueryInterface(ma_completion_handler_uwp* pThis, const IID* const riid, void** ppObject)
{
    /*
    We need to "implement" IAgileObject which is just an indicator that's used internally by WASAPI for some multithreading management. To
    "implement" this, we just make sure we return pThis when the IAgileObject is requested.
    */
    if (!ma_is_guid_equal(riid, &MA_IID_IUnknown) && !ma_is_guid_equal(riid, &MA_IID_IActivateAudioInterfaceCompletionHandler) && !ma_is_guid_equal(riid, &MA_IID_IAgileObject)) {
        *ppObject = NULL;
        return E_NOINTERFACE;
    }

    /* Getting here means the IID is IUnknown or IMMNotificationClient. */
    *ppObject = (void*)pThis;
    ((ma_completion_handler_uwp_vtbl*)pThis->lpVtbl)->AddRef(pThis);
    return S_OK;
}

static ULONG STDMETHODCALLTYPE ma_completion_handler_uwp_AddRef(ma_completion_handler_uwp* pThis)
{
    return (ULONG)ma_atomic_fetch_add_32(&pThis->counter, 1) + 1;
}

static ULONG STDMETHODCALLTYPE ma_completion_handler_uwp_Release(ma_completion_handler_uwp* pThis)
{
    ma_uint32 newRefCount = ma_atomic_fetch_sub_32(&pThis->counter, 1) - 1;
    if (newRefCount == 0) {
        return 0;   /* We don't free anything here because we never allocate the object on the heap. */
    }

    return (ULONG)newRefCount;
}

static HRESULT STDMETHODCALLTYPE ma_completion_handler_uwp_ActivateCompleted(ma_completion_handler_uwp* pThis, ma_IActivateAudioInterfaceAsyncOperation* pActivateOperation)
{
    (void)pActivateOperation;
    SetEvent(pThis->hEvent);
    return S_OK;
}


static ma_completion_handler_uwp_vtbl g_maCompletionHandlerVtblInstance = {
    ma_completion_handler_uwp_QueryInterface,
    ma_completion_handler_uwp_AddRef,
    ma_completion_handler_uwp_Release,
    ma_completion_handler_uwp_ActivateCompleted
};

static ma_result ma_completion_handler_uwp_init(ma_completion_handler_uwp* pHandler)
{
    MA_ASSERT(pHandler != NULL);
    MA_ZERO_OBJECT(pHandler);

    pHandler->lpVtbl = &g_maCompletionHandlerVtblInstance;
    pHandler->counter = 1;
    pHandler->hEvent = CreateEventA(NULL, FALSE, FALSE, NULL);
    if (pHandler->hEvent == NULL) {
        return ma_result_from_GetLastError(GetLastError());
    }

    return MA_SUCCESS;
}

static void ma_completion_handler_uwp_uninit(ma_completion_handler_uwp* pHandler)
{
    if (pHandler->hEvent != NULL) {
        CloseHandle(pHandler->hEvent);
    }
}

static void ma_completion_handler_uwp_wait(ma_completion_handler_uwp* pHandler)
{
    WaitForSingleObject((HANDLE)pHandler->hEvent, INFINITE);
}
#endif  /* !MA_WIN32_DESKTOP */

/* We need a virtual table for our notification client object that's used for detecting changes to the default device. */
#if defined(MA_WIN32_DESKTOP) || defined(MA_WIN32_GDK)
static HRESULT STDMETHODCALLTYPE ma_IMMNotificationClient_QueryInterface(ma_IMMNotificationClient* pThis, const IID* const riid, void** ppObject)
{
    /*
    We care about two interfaces - IUnknown and IMMNotificationClient. If the requested IID is something else
    we just return E_NOINTERFACE. Otherwise we need to increment the reference counter and return S_OK.
    */
    if (!ma_is_guid_equal(riid, &MA_IID_IUnknown) && !ma_is_guid_equal(riid, &MA_IID_IMMNotificationClient)) {
        *ppObject = NULL;
        return E_NOINTERFACE;
    }

    /* Getting here means the IID is IUnknown or IMMNotificationClient. */
    *ppObject = (void*)pThis;
    ((ma_IMMNotificationClientVtbl*)pThis->lpVtbl)->AddRef(pThis);
    return S_OK;
}

static ULONG STDMETHODCALLTYPE ma_IMMNotificationClient_AddRef(ma_IMMNotificationClient* pThis)
{
    return (ULONG)ma_atomic_fetch_add_32(&pThis->counter, 1) + 1;
}

static ULONG STDMETHODCALLTYPE ma_IMMNotificationClient_Release(ma_IMMNotificationClient* pThis)
{
    ma_uint32 newRefCount = ma_atomic_fetch_sub_32(&pThis->counter, 1) - 1;
    if (newRefCount == 0) {
        return 0;   /* We don't free anything here because we never allocate the object on the heap. */
    }

    return (ULONG)newRefCount;
}

static HRESULT STDMETHODCALLTYPE ma_IMMNotificationClient_OnDeviceStateChanged(ma_IMMNotificationClient* pThis, const WCHAR* pDeviceID, DWORD dwNewState)
{
    ma_bool32 isThisDevice = MA_FALSE;
    ma_bool32 isCapture    = MA_FALSE;
    ma_bool32 isPlayback   = MA_FALSE;

#ifdef MA_DEBUG_OUTPUT
    /*ma_log_postf(ma_device_get_log(pThis->pDevice), MA_LOG_LEVEL_DEBUG, "IMMNotificationClient_OnDeviceStateChanged(pDeviceID=%S, dwNewState=%u)\n", (pDeviceID != NULL) ? pDeviceID : L"(NULL)", (unsigned int)dwNewState);*/
#endif

    /*
    There have been reports of a hang when a playback device is disconnected. The idea with this code is to explicitly stop the device if we detect
    that the device is disabled or has been unplugged.
    */
    if (pThis->pDevice->wasapi.allowCaptureAutoStreamRouting && (pThis->pDevice->type == ma_device_type_capture || pThis->pDevice->type == ma_device_type_duplex || pThis->pDevice->type == ma_device_type_loopback)) {
        isCapture = MA_TRUE;
        if (ma_strcmp_WCHAR(pThis->pDevice->capture.id.wasapi, pDeviceID) == 0) {
            isThisDevice = MA_TRUE;
        }
    }

    if (pThis->pDevice->wasapi.allowPlaybackAutoStreamRouting && (pThis->pDevice->type == ma_device_type_playback || pThis->pDevice->type == ma_device_type_duplex)) {
        isPlayback = MA_TRUE;
        if (ma_strcmp_WCHAR(pThis->pDevice->playback.id.wasapi, pDeviceID) == 0) {
            isThisDevice = MA_TRUE;
        }
    }


    /*
    If the device ID matches our device we need to mark our device as detached and stop it. When a
    device is added in OnDeviceAdded(), we'll restart it. We only mark it as detached if the device
    was started at the time of being removed.
    */
    if (isThisDevice) {
        if ((dwNewState & MA_MM_DEVICE_STATE_ACTIVE) == 0) {
            /*
            Unplugged or otherwise unavailable. Mark as detached if we were in a playing state. We'll
            use this to determine whether or not we need to automatically start the device when it's
            plugged back in again.
            */
            if (ma_device_get_state(pThis->pDevice) == ma_device_state_started) {
                if (isPlayback) {
                    pThis->pDevice->wasapi.isDetachedPlayback = MA_TRUE;
                }
                if (isCapture) {
                    pThis->pDevice->wasapi.isDetachedCapture = MA_TRUE;
                }

                ma_device_stop(pThis->pDevice);
            }
        }

        if ((dwNewState & MA_MM_DEVICE_STATE_ACTIVE) != 0) {
            /* The device was activated. If we were detached, we need to start it again. */
            ma_bool8 tryRestartingDevice = MA_FALSE;

            if (isPlayback) {
                if (pThis->pDevice->wasapi.isDetachedPlayback) {
                    pThis->pDevice->wasapi.isDetachedPlayback = MA_FALSE;
                    ma_device_reroute__wasapi(pThis->pDevice, ma_device_type_playback);
                    tryRestartingDevice = MA_TRUE;
                }
            }

            if (isCapture) {
                if (pThis->pDevice->wasapi.isDetachedCapture) {
                    pThis->pDevice->wasapi.isDetachedCapture = MA_FALSE;
                    ma_device_reroute__wasapi(pThis->pDevice, (pThis->pDevice->type == ma_device_type_loopback) ? ma_device_type_loopback : ma_device_type_capture);
                    tryRestartingDevice = MA_TRUE;
                }
            }

            if (tryRestartingDevice) {
                if (pThis->pDevice->wasapi.isDetachedPlayback == MA_FALSE && pThis->pDevice->wasapi.isDetachedCapture == MA_FALSE) {
                    ma_device_start(pThis->pDevice);
                }
            }
        }
    }

    return S_OK;
}

static HRESULT STDMETHODCALLTYPE ma_IMMNotificationClient_OnDeviceAdded(ma_IMMNotificationClient* pThis, const WCHAR* pDeviceID)
{
#ifdef MA_DEBUG_OUTPUT
    /*ma_log_postf(ma_device_get_log(pThis->pDevice), MA_LOG_LEVEL_DEBUG, "IMMNotificationClient_OnDeviceAdded(pDeviceID=%S)\n", (pDeviceID != NULL) ? pDeviceID : L"(NULL)");*/
#endif

    /* We don't need to worry about this event for our purposes. */
    (void)pThis;
    (void)pDeviceID;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE ma_IMMNotificationClient_OnDeviceRemoved(ma_IMMNotificationClient* pThis, const WCHAR* pDeviceID)
{
#ifdef MA_DEBUG_OUTPUT
    /*ma_log_postf(ma_device_get_log(pThis->pDevice), MA_LOG_LEVEL_DEBUG, "IMMNotificationClient_OnDeviceRemoved(pDeviceID=%S)\n", (pDeviceID != NULL) ? pDeviceID : L"(NULL)");*/
#endif

    /* We don't need to worry about this event for our purposes. */
    (void)pThis;
    (void)pDeviceID;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE ma_IMMNotificationClient_OnDefaultDeviceChanged(ma_IMMNotificationClient* pThis, ma_EDataFlow dataFlow, ma_ERole role, const WCHAR* pDefaultDeviceID)
{
#ifdef MA_DEBUG_OUTPUT
    /*ma_log_postf(ma_device_get_log(pThis->pDevice), MA_LOG_LEVEL_DEBUG, "IMMNotificationClient_OnDefaultDeviceChanged(dataFlow=%d, role=%d, pDefaultDeviceID=%S)\n", dataFlow, role, (pDefaultDeviceID != NULL) ? pDefaultDeviceID : L"(NULL)");*/
#endif

    (void)role;

    /* We only care about devices with the same data flow as the current device. */
    if ((pThis->pDevice->type == ma_device_type_playback && dataFlow != ma_eRender)  ||
        (pThis->pDevice->type == ma_device_type_capture  && dataFlow != ma_eCapture) ||
        (pThis->pDevice->type == ma_device_type_loopback && dataFlow != ma_eRender)) {
        ma_log_postf(ma_device_get_log(pThis->pDevice), MA_LOG_LEVEL_DEBUG, "[WASAPI] Stream rerouting abandoned because dataFlow does match device type.\n");
        return S_OK;
    }

    /* We need to consider dataFlow as ma_eCapture if device is ma_device_type_loopback */
    if (pThis->pDevice->type == ma_device_type_loopback) {
        dataFlow = ma_eCapture;
    }

    /* Don't do automatic stream routing if we're not allowed. */
    if ((dataFlow == ma_eRender  && pThis->pDevice->wasapi.allowPlaybackAutoStreamRouting == MA_FALSE) ||
        (dataFlow == ma_eCapture && pThis->pDevice->wasapi.allowCaptureAutoStreamRouting  == MA_FALSE)) {
        ma_log_postf(ma_device_get_log(pThis->pDevice), MA_LOG_LEVEL_DEBUG, "[WASAPI] Stream rerouting abandoned because automatic stream routing has been disabled by the device config.\n");
        return S_OK;
    }

    /*
    Not currently supporting automatic stream routing in exclusive mode. This is not working correctly on my machine due to
    AUDCLNT_E_DEVICE_IN_USE errors when reinitializing the device. If this is a bug in miniaudio, we can try re-enabling this once
    it's fixed.
    */
    if ((dataFlow == ma_eRender  && pThis->pDevice->playback.shareMode == ma_share_mode_exclusive) ||
        (dataFlow == ma_eCapture && pThis->pDevice->capture.shareMode  == ma_share_mode_exclusive)) {
        ma_log_postf(ma_device_get_log(pThis->pDevice), MA_LOG_LEVEL_DEBUG, "[WASAPI] Stream rerouting abandoned because the device shared mode is exclusive.\n");
        return S_OK;
    }



    /*
    Second attempt at device rerouting. We're going to retrieve the device's state at the time of
    the route change. We're then going to stop the device, reinitialize the device, and then start
    it again if the state before stopping was ma_device_state_started.
    */
    {
        ma_uint32 previousState = ma_device_get_state(pThis->pDevice);
        ma_bool8 restartDevice = MA_FALSE;

        if (previousState == ma_device_state_uninitialized || previousState == ma_device_state_starting) {
            ma_log_postf(ma_device_get_log(pThis->pDevice), MA_LOG_LEVEL_DEBUG, "[WASAPI] Stream rerouting abandoned because the device is in the process of starting.\n");
            return S_OK;
        }

        if (previousState == ma_device_state_started) {
            ma_device_stop(pThis->pDevice);
            restartDevice = MA_TRUE;
        }

        if (pDefaultDeviceID != NULL) { /* <-- The input device ID will be null if there's no other device available. */
            ma_mutex_lock(&pThis->pDevice->wasapi.rerouteLock);
            {
                if (dataFlow == ma_eRender) {
                    ma_device_reroute__wasapi(pThis->pDevice, ma_device_type_playback);

                    if (pThis->pDevice->wasapi.isDetachedPlayback) {
                        pThis->pDevice->wasapi.isDetachedPlayback = MA_FALSE;

                        if (pThis->pDevice->type == ma_device_type_duplex && pThis->pDevice->wasapi.isDetachedCapture) {
                            restartDevice = MA_FALSE;   /* It's a duplex device and the capture side is detached. We cannot be restarting the device just yet. */
                        }
                        else {
                            restartDevice = MA_TRUE;    /* It's not a duplex device, or the capture side is also attached so we can go ahead and restart the device. */
                        }
                    }
                }
                else {
                    ma_device_reroute__wasapi(pThis->pDevice, (pThis->pDevice->type == ma_device_type_loopback) ? ma_device_type_loopback : ma_device_type_capture);

                    if (pThis->pDevice->wasapi.isDetachedCapture) {
                        pThis->pDevice->wasapi.isDetachedCapture = MA_FALSE;

                        if (pThis->pDevice->type == ma_device_type_duplex && pThis->pDevice->wasapi.isDetachedPlayback) {
                            restartDevice = MA_FALSE;   /* It's a duplex device and the playback side is detached. We cannot be restarting the device just yet. */
                        }
                        else {
                            restartDevice = MA_TRUE;    /* It's not a duplex device, or the playback side is also attached so we can go ahead and restart the device. */
                        }
                    }
                }
            }
            ma_mutex_unlock(&pThis->pDevice->wasapi.rerouteLock);

            if (restartDevice) {
                ma_device_start(pThis->pDevice);
            }
        }
    }

    return S_OK;
}

static HRESULT STDMETHODCALLTYPE ma_IMMNotificationClient_OnPropertyValueChanged(ma_IMMNotificationClient* pThis, const WCHAR* pDeviceID, const PROPERTYKEY key)
{
#ifdef MA_DEBUG_OUTPUT
    /*ma_log_postf(ma_device_get_log(pThis->pDevice), MA_LOG_LEVEL_DEBUG, "IMMNotificationClient_OnPropertyValueChanged(pDeviceID=%S)\n", (pDeviceID != NULL) ? pDeviceID : L"(NULL)");*/
#endif

    (void)pThis;
    (void)pDeviceID;
    (void)key;
    return S_OK;
}

static ma_IMMNotificationClientVtbl g_maNotificationCientVtbl = {
    ma_IMMNotificationClient_QueryInterface,
    ma_IMMNotificationClient_AddRef,
    ma_IMMNotificationClient_Release,
    ma_IMMNotificationClient_OnDeviceStateChanged,
    ma_IMMNotificationClient_OnDeviceAdded,
    ma_IMMNotificationClient_OnDeviceRemoved,
    ma_IMMNotificationClient_OnDefaultDeviceChanged,
    ma_IMMNotificationClient_OnPropertyValueChanged
};
#endif  /* MA_WIN32_DESKTOP */

static const char* ma_to_usage_string__wasapi(ma_wasapi_usage usage)
{
    switch (usage)
    {
        case ma_wasapi_usage_default:   return NULL;
        case ma_wasapi_usage_games:     return "Games";
        case ma_wasapi_usage_pro_audio: return "Pro Audio";
        default: break;
    }

    return NULL;
}

#if defined(MA_WIN32_DESKTOP) || defined(MA_WIN32_GDK)
typedef ma_IMMDevice ma_WASAPIDeviceInterface;
#else
typedef ma_IUnknown ma_WASAPIDeviceInterface;
#endif


#define MA_CONTEXT_COMMAND_QUIT__WASAPI                 1
#define MA_CONTEXT_COMMAND_CREATE_IAUDIOCLIENT__WASAPI  2
#define MA_CONTEXT_COMMAND_RELEASE_IAUDIOCLIENT__WASAPI 3

static ma_context_command__wasapi ma_context_init_command__wasapi(int code)
{
    ma_context_command__wasapi cmd;

    MA_ZERO_OBJECT(&cmd);
    cmd.code = code;

    return cmd;
}

static ma_result ma_context_post_command__wasapi(ma_context* pContext, const ma_context_command__wasapi* pCmd)
{
    /* For now we are doing everything synchronously, but I might relax this later if the need arises. */
    ma_result result;
    ma_bool32 isUsingLocalEvent = MA_FALSE;
    ma_event localEvent;

    MA_ASSERT(pContext != NULL);
    MA_ASSERT(pCmd     != NULL);

    if (pCmd->pEvent == NULL) {
        isUsingLocalEvent = MA_TRUE;

        result = ma_event_init(&localEvent);
        if (result != MA_SUCCESS) {
            return result;  /* Failed to create the event for this command. */
        }
    }

    /* Here is where we add the command to the list. If there's not enough room we'll spin until there is. */
    ma_mutex_lock(&pContext->wasapi.commandLock);
    {
        ma_uint32 index;

        /* Spin until we've got some space available. */
        while (pContext->wasapi.commandCount == ma_countof(pContext->wasapi.commands)) {
            ma_yield();
        }

        /* Space is now available. Can safely add to the list. */
        index = (pContext->wasapi.commandIndex + pContext->wasapi.commandCount) % ma_countof(pContext->wasapi.commands);
        pContext->wasapi.commands[index]        = *pCmd;
        pContext->wasapi.commands[index].pEvent = &localEvent;
        pContext->wasapi.commandCount += 1;

        /* Now that the command has been added, release the semaphore so ma_context_next_command__wasapi() can return. */
        ma_semaphore_release(&pContext->wasapi.commandSem);
    }
    ma_mutex_unlock(&pContext->wasapi.commandLock);

    if (isUsingLocalEvent) {
        ma_event_wait(&localEvent);
        ma_event_uninit(&localEvent);
    }

    return MA_SUCCESS;
}

static ma_result ma_context_next_command__wasapi(ma_context* pContext, ma_context_command__wasapi* pCmd)
{
    ma_result result = MA_SUCCESS;

    MA_ASSERT(pContext != NULL);
    MA_ASSERT(pCmd     != NULL);

    result = ma_semaphore_wait(&pContext->wasapi.commandSem);
    if (result == MA_SUCCESS) {
        ma_mutex_lock(&pContext->wasapi.commandLock);
        {
            *pCmd = pContext->wasapi.commands[pContext->wasapi.commandIndex];
            pContext->wasapi.commandIndex  = (pContext->wasapi.commandIndex + 1) % ma_countof(pContext->wasapi.commands);
            pContext->wasapi.commandCount -= 1;
        }
        ma_mutex_unlock(&pContext->wasapi.commandLock);
    }

    return result;
}

static ma_thread_result MA_THREADCALL ma_context_command_thread__wasapi(void* pUserData)
{
    ma_result result;
    ma_context* pContext = (ma_context*)pUserData;
    MA_ASSERT(pContext != NULL);

    for (;;) {
        ma_context_command__wasapi cmd;
        result = ma_context_next_command__wasapi(pContext, &cmd);
        if (result != MA_SUCCESS) {
            break;
        }

        switch (cmd.code)
        {
            case MA_CONTEXT_COMMAND_QUIT__WASAPI:
            {
                /* Do nothing. Handled after the switch. */
            } break;

            case MA_CONTEXT_COMMAND_CREATE_IAUDIOCLIENT__WASAPI:
            {
                if (cmd.data.createAudioClient.deviceType == ma_device_type_playback) {
                    *cmd.data.createAudioClient.pResult = ma_result_from_HRESULT(ma_IAudioClient_GetService((ma_IAudioClient*)cmd.data.createAudioClient.pAudioClient, &MA_IID_IAudioRenderClient, cmd.data.createAudioClient.ppAudioClientService));
                } else {
                    *cmd.data.createAudioClient.pResult = ma_result_from_HRESULT(ma_IAudioClient_GetService((ma_IAudioClient*)cmd.data.createAudioClient.pAudioClient, &MA_IID_IAudioCaptureClient, cmd.data.createAudioClient.ppAudioClientService));
                }
            } break;

            case MA_CONTEXT_COMMAND_RELEASE_IAUDIOCLIENT__WASAPI:
            {
                if (cmd.data.releaseAudioClient.deviceType == ma_device_type_playback) {
                    if (cmd.data.releaseAudioClient.pDevice->wasapi.pAudioClientPlayback != NULL) {
                        ma_IAudioClient_Release((ma_IAudioClient*)cmd.data.releaseAudioClient.pDevice->wasapi.pAudioClientPlayback);
                        cmd.data.releaseAudioClient.pDevice->wasapi.pAudioClientPlayback = NULL;
                    }
                }

                if (cmd.data.releaseAudioClient.deviceType == ma_device_type_capture) {
                    if (cmd.data.releaseAudioClient.pDevice->wasapi.pAudioClientCapture != NULL) {
                        ma_IAudioClient_Release((ma_IAudioClient*)cmd.data.releaseAudioClient.pDevice->wasapi.pAudioClientCapture);
                        cmd.data.releaseAudioClient.pDevice->wasapi.pAudioClientCapture = NULL;
                    }
                }
            } break;

            default:
            {
                /* Unknown command. Ignore it, but trigger an assert in debug mode so we're aware of it. */
                MA_ASSERT(MA_FALSE);
            } break;
        }

        if (cmd.pEvent != NULL) {
            ma_event_signal(cmd.pEvent);
        }

        if (cmd.code == MA_CONTEXT_COMMAND_QUIT__WASAPI) {
            break;  /* Received a quit message. Get out of here. */
        }
    }

    return (ma_thread_result)0;
}

static ma_result ma_device_create_IAudioClient_service__wasapi(ma_context* pContext, ma_device_type deviceType, ma_IAudioClient* pAudioClient, void** ppAudioClientService)
{
    ma_result result;
    ma_result cmdResult;
    ma_context_command__wasapi cmd = ma_context_init_command__wasapi(MA_CONTEXT_COMMAND_CREATE_IAUDIOCLIENT__WASAPI);
    cmd.data.createAudioClient.deviceType           = deviceType;
    cmd.data.createAudioClient.pAudioClient         = (void*)pAudioClient;
    cmd.data.createAudioClient.ppAudioClientService = ppAudioClientService;
    cmd.data.createAudioClient.pResult              = &cmdResult;   /* Declared locally, but won't be dereferenced after this function returns since execution of the command will wait here. */

    result = ma_context_post_command__wasapi(pContext, &cmd);  /* This will not return until the command has actually been run. */
    if (result != MA_SUCCESS) {
        return result;
    }

    return *cmd.data.createAudioClient.pResult;
}

#if 0   /* Not used at the moment, but leaving here for future use. */
static ma_result ma_device_release_IAudioClient_service__wasapi(ma_device* pDevice, ma_device_type deviceType)
{
    ma_result result;
    ma_context_command__wasapi cmd = ma_context_init_command__wasapi(MA_CONTEXT_COMMAND_RELEASE_IAUDIOCLIENT__WASAPI);
    cmd.data.releaseAudioClient.pDevice    = pDevice;
    cmd.data.releaseAudioClient.deviceType = deviceType;

    result = ma_context_post_command__wasapi(pDevice->pContext, &cmd);  /* This will not return until the command has actually been run. */
    if (result != MA_SUCCESS) {
        return result;
    }

    return MA_SUCCESS;
}
#endif


static void ma_add_native_data_format_to_device_info_from_WAVEFORMATEX(const MA_WAVEFORMATEX* pWF, ma_share_mode shareMode, ma_device_info* pInfo)
{
    MA_ASSERT(pWF != NULL);
    MA_ASSERT(pInfo != NULL);

    if (pInfo->nativeDataFormatCount >= ma_countof(pInfo->nativeDataFormats)) {
        return; /* Too many data formats. Need to ignore this one. Don't think this should ever happen with WASAPI. */
    }

    pInfo->nativeDataFormats[pInfo->nativeDataFormatCount].format     = ma_format_from_WAVEFORMATEX(pWF);
    pInfo->nativeDataFormats[pInfo->nativeDataFormatCount].channels   = pWF->nChannels;
    pInfo->nativeDataFormats[pInfo->nativeDataFormatCount].sampleRate = pWF->nSamplesPerSec;
    pInfo->nativeDataFormats[pInfo->nativeDataFormatCount].flags      = (shareMode == ma_share_mode_exclusive) ? MA_DATA_FORMAT_FLAG_EXCLUSIVE_MODE : 0;
    pInfo->nativeDataFormatCount += 1;
}

static ma_result ma_context_get_device_info_from_IAudioClient__wasapi(ma_context* pContext, /*ma_IMMDevice**/void* pMMDevice, ma_IAudioClient* pAudioClient, ma_device_info* pInfo)
{
    HRESULT hr;
    MA_WAVEFORMATEX* pWF = NULL;

    MA_ASSERT(pAudioClient != NULL);
    MA_ASSERT(pInfo != NULL);

    /* Shared Mode. We use GetMixFormat() here. */
    hr = ma_IAudioClient_GetMixFormat((ma_IAudioClient*)pAudioClient, (MA_WAVEFORMATEX**)&pWF);
    if (SUCCEEDED(hr)) {
        ma_add_native_data_format_to_device_info_from_WAVEFORMATEX(pWF, ma_share_mode_shared, pInfo);
    } else {
        ma_log_postf(ma_context_get_log(pContext), MA_LOG_LEVEL_ERROR, "[WASAPI] Failed to retrieve mix format for device info retrieval.");
        return ma_result_from_HRESULT(hr);
    }

    /*
    Exlcusive Mode. We repeatedly call IsFormatSupported() here. This is not currently supported on
    UWP. Failure to retrieve the exclusive mode format is not considered an error, so from here on
    out, MA_SUCCESS is guaranteed to be returned.
    */
    #if defined(MA_WIN32_DESKTOP) || defined(MA_WIN32_GDK)
    {
        ma_IPropertyStore *pProperties;

        /*
        The first thing to do is get the format from PKEY_AudioEngine_DeviceFormat. This should give us a channel count we assume is
        correct which will simplify our searching.
        */
        hr = ma_IMMDevice_OpenPropertyStore((ma_IMMDevice*)pMMDevice, STGM_READ, &pProperties);
        if (SUCCEEDED(hr)) {
            MA_PROPVARIANT var;
            ma_PropVariantInit(&var);

            hr = ma_IPropertyStore_GetValue(pProperties, &MA_PKEY_AudioEngine_DeviceFormat, &var);
            if (SUCCEEDED(hr)) {
                pWF = (MA_WAVEFORMATEX*)var.blob.pBlobData;

                /*
                In my testing, the format returned by PKEY_AudioEngine_DeviceFormat is suitable for exclusive mode so we check this format
                first. If this fails, fall back to a search.
                */
                hr = ma_IAudioClient_IsFormatSupported((ma_IAudioClient*)pAudioClient, MA_AUDCLNT_SHAREMODE_EXCLUSIVE, pWF, NULL);
                if (SUCCEEDED(hr)) {
                    /* The format returned by PKEY_AudioEngine_DeviceFormat is supported. */
                    ma_add_native_data_format_to_device_info_from_WAVEFORMATEX(pWF, ma_share_mode_exclusive, pInfo);
                } else {
                    /*
                    The format returned by PKEY_AudioEngine_DeviceFormat is not supported, so fall back to a search. We assume the channel
                    count returned by MA_PKEY_AudioEngine_DeviceFormat is valid and correct. For simplicity we're only returning one format.
                    */
                    ma_uint32 channels = pWF->nChannels;
                    ma_channel defaultChannelMap[MA_MAX_CHANNELS];
                    MA_WAVEFORMATEXTENSIBLE wf;
                    ma_bool32 found;
                    ma_uint32 iFormat;

                    /* Make sure we don't overflow the channel map. */
                    if (channels > MA_MAX_CHANNELS) {
                        channels = MA_MAX_CHANNELS;
                    }

                    ma_channel_map_init_standard(ma_standard_channel_map_microsoft, defaultChannelMap, ma_countof(defaultChannelMap), channels);

                    MA_ZERO_OBJECT(&wf);
                    wf.cbSize     = sizeof(wf);
                    wf.wFormatTag = WAVE_FORMAT_EXTENSIBLE;
                    wf.nChannels  = (WORD)channels;
                    wf.dwChannelMask     = ma_channel_map_to_channel_mask__win32(defaultChannelMap, channels);

                    found = MA_FALSE;
                    for (iFormat = 0; iFormat < ma_countof(g_maFormatPriorities); ++iFormat) {
                        ma_format format = g_maFormatPriorities[iFormat];
                        ma_uint32 iSampleRate;

                        wf.wBitsPerSample       = (WORD)(ma_get_bytes_per_sample(format)*8);
                        wf.nBlockAlign          = (WORD)(wf.nChannels * wf.wBitsPerSample / 8);
                        wf.nAvgBytesPerSec      = wf.nBlockAlign * wf.nSamplesPerSec;
                        wf.Samples.wValidBitsPerSample = /*(format == ma_format_s24_32) ? 24 :*/ wf.wBitsPerSample;
                        if (format == ma_format_f32) {
                            wf.SubFormat = MA_GUID_KSDATAFORMAT_SUBTYPE_IEEE_FLOAT;
                        } else {
                            wf.SubFormat = MA_GUID_KSDATAFORMAT_SUBTYPE_PCM;
                        }

                        for (iSampleRate = 0; iSampleRate < ma_countof(g_maStandardSampleRatePriorities); ++iSampleRate) {
                            wf.nSamplesPerSec = g_maStandardSampleRatePriorities[iSampleRate];

                            hr = ma_IAudioClient_IsFormatSupported((ma_IAudioClient*)pAudioClient, MA_AUDCLNT_SHAREMODE_EXCLUSIVE, (MA_WAVEFORMATEX*)&wf, NULL);
                            if (SUCCEEDED(hr)) {
                                ma_add_native_data_format_to_device_info_from_WAVEFORMATEX((MA_WAVEFORMATEX*)&wf, ma_share_mode_exclusive, pInfo);
                                found = MA_TRUE;
                                break;
                            }
                        }

                        if (found) {
                            break;
                        }
                    }

                    ma_PropVariantClear(pContext, &var);

                    if (!found) {
                        ma_log_postf(ma_context_get_log(pContext), MA_LOG_LEVEL_WARNING, "[WASAPI] Failed to find suitable device format for device info retrieval.");
                    }
                }
            } else {
                ma_log_postf(ma_context_get_log(pContext), MA_LOG_LEVEL_WARNING, "[WASAPI] Failed to retrieve device format for device info retrieval.");
            }

            ma_IPropertyStore_Release(pProperties);
        } else {
            ma_log_postf(ma_context_get_log(pContext), MA_LOG_LEVEL_WARNING, "[WASAPI] Failed to open property store for device info retrieval.");
        }
    }
    #else
    {
        (void)pMMDevice;    /* Unused. */
    }
    #endif

    return MA_SUCCESS;
}

#if defined(MA_WIN32_DESKTOP) || defined(MA_WIN32_GDK)
static ma_EDataFlow ma_device_type_to_EDataFlow(ma_device_type deviceType)
{
    if (deviceType == ma_device_type_playback) {
        return ma_eRender;
    } else if (deviceType == ma_device_type_capture) {
        return ma_eCapture;
    } else {
        MA_ASSERT(MA_FALSE);
        return ma_eRender; /* Should never hit this. */
    }
}

static ma_result ma_context_create_IMMDeviceEnumerator__wasapi(ma_context* pContext, ma_IMMDeviceEnumerator** ppDeviceEnumerator)
{
    HRESULT hr;
    ma_IMMDeviceEnumerator* pDeviceEnumerator;

    MA_ASSERT(pContext           != NULL);
    MA_ASSERT(ppDeviceEnumerator != NULL);

    *ppDeviceEnumerator = NULL; /* Safety. */

    hr = ma_CoCreateInstance(pContext, &MA_CLSID_MMDeviceEnumerator, NULL, CLSCTX_ALL, &MA_IID_IMMDeviceEnumerator, (void**)&pDeviceEnumerator);
    if (FAILED(hr)) {
        ma_log_postf(ma_context_get_log(pContext), MA_LOG_LEVEL_ERROR, "[WASAPI] Failed to create device enumerator.");
        return ma_result_from_HRESULT(hr);
    }

    *ppDeviceEnumerator = pDeviceEnumerator;

    return MA_SUCCESS;
}

static WCHAR* ma_context_get_default_device_id_from_IMMDeviceEnumerator__wasapi(ma_context* pContext, ma_IMMDeviceEnumerator* pDeviceEnumerator, ma_device_type deviceType)
{
    HRESULT hr;
    ma_IMMDevice* pMMDefaultDevice = NULL;
    WCHAR* pDefaultDeviceID = NULL;
    ma_EDataFlow dataFlow;
    ma_ERole role;

    MA_ASSERT(pContext          != NULL);
    MA_ASSERT(pDeviceEnumerator != NULL);

    (void)pContext;

    /* Grab the EDataFlow type from the device type. */
    dataFlow = ma_device_type_to_EDataFlow(deviceType);

    /* The role is always eConsole, but we may make this configurable later. */
    role = ma_eConsole;

    hr = ma_IMMDeviceEnumerator_GetDefaultAudioEndpoint(pDeviceEnumerator, dataFlow, role, &pMMDefaultDevice);
    if (FAILED(hr)) {
        return NULL;
    }

    hr = ma_IMMDevice_GetId(pMMDefaultDevice, &pDefaultDeviceID);

    ma_IMMDevice_Release(pMMDefaultDevice);
    pMMDefaultDevice = NULL;

    if (FAILED(hr)) {
        return NULL;
    }

    return pDefaultDeviceID;
}

static WCHAR* ma_context_get_default_device_id__wasapi(ma_context* pContext, ma_device_type deviceType)    /* Free the returned pointer with ma_CoTaskMemFree() */
{
    ma_result result;
    ma_IMMDeviceEnumerator* pDeviceEnumerator;
    WCHAR* pDefaultDeviceID = NULL;

    MA_ASSERT(pContext != NULL);

    result = ma_context_create_IMMDeviceEnumerator__wasapi(pContext, &pDeviceEnumerator);
    if (result != MA_SUCCESS) {
        return NULL;
    }

    pDefaultDeviceID = ma_context_get_default_device_id_from_IMMDeviceEnumerator__wasapi(pContext, pDeviceEnumerator, deviceType);

    ma_IMMDeviceEnumerator_Release(pDeviceEnumerator);
    return pDefaultDeviceID;
}

static ma_result ma_context_get_MMDevice__wasapi(ma_context* pContext, ma_device_type deviceType, const ma_device_id* pDeviceID, ma_IMMDevice** ppMMDevice)
{
    ma_IMMDeviceEnumerator* pDeviceEnumerator;
    HRESULT hr;

    MA_ASSERT(pContext != NULL);
    MA_ASSERT(ppMMDevice != NULL);

    hr = ma_CoCreateInstance(pContext, &MA_CLSID_MMDeviceEnumerator, NULL, CLSCTX_ALL, &MA_IID_IMMDeviceEnumerator, (void**)&pDeviceEnumerator);
    if (FAILED(hr)) {
        ma_log_postf(ma_context_get_log(pContext), MA_LOG_LEVEL_ERROR, "[WASAPI] Failed to create IMMDeviceEnumerator.\n");
        return ma_result_from_HRESULT(hr);
    }

    if (pDeviceID == NULL) {
        hr = ma_IMMDeviceEnumerator_GetDefaultAudioEndpoint(pDeviceEnumerator, (deviceType == ma_device_type_capture) ? ma_eCapture : ma_eRender, ma_eConsole, ppMMDevice);
    } else {
        hr = ma_IMMDeviceEnumerator_GetDevice(pDeviceEnumerator, pDeviceID->wasapi, ppMMDevice);
    }

    ma_IMMDeviceEnumerator_Release(pDeviceEnumerator);
    if (FAILED(hr)) {
        ma_log_postf(ma_context_get_log(pContext), MA_LOG_LEVEL_ERROR, "[WASAPI] Failed to retrieve IMMDevice.\n");
        return ma_result_from_HRESULT(hr);
    }

    return MA_SUCCESS;
}

static ma_result ma_context_get_device_id_from_MMDevice__wasapi(ma_context* pContext, ma_IMMDevice* pMMDevice, ma_device_id* pDeviceID)
{
    WCHAR* pDeviceIDString;
    HRESULT hr;

    MA_ASSERT(pDeviceID != NULL);

    hr = ma_IMMDevice_GetId(pMMDevice, &pDeviceIDString);
    if (SUCCEEDED(hr)) {
        size_t idlen = ma_strlen_WCHAR(pDeviceIDString);
        if (idlen+1 > ma_countof(pDeviceID->wasapi)) {
            ma_CoTaskMemFree(pContext, pDeviceIDString);
            MA_ASSERT(MA_FALSE);  /* NOTE: If this is triggered, please report it. It means the format of the ID must haved change and is too long to fit in our fixed sized buffer. */
            return MA_ERROR;
        }

        MA_COPY_MEMORY(pDeviceID->wasapi, pDeviceIDString, idlen * sizeof(wchar_t));
        pDeviceID->wasapi[idlen] = '\0';

        ma_CoTaskMemFree(pContext, pDeviceIDString);

        return MA_SUCCESS;
    }

    return MA_ERROR;
}

static ma_result ma_context_get_device_info_from_MMDevice__wasapi(ma_context* pContext, ma_IMMDevice* pMMDevice, WCHAR* pDefaultDeviceID, ma_bool32 onlySimpleInfo, ma_device_info* pInfo)
{
    ma_result result;
    HRESULT hr;

    MA_ASSERT(pContext != NULL);
    MA_ASSERT(pMMDevice != NULL);
    MA_ASSERT(pInfo != NULL);

    /* ID. */
    result = ma_context_get_device_id_from_MMDevice__wasapi(pContext, pMMDevice, &pInfo->id);
    if (result == MA_SUCCESS) {
        if (pDefaultDeviceID != NULL) {
            if (ma_strcmp_WCHAR(pInfo->id.wasapi, pDefaultDeviceID) == 0) {
                pInfo->isDefault = MA_TRUE;
            }
        }
    }

    /* Description / Friendly Name */
    {
        ma_IPropertyStore *pProperties;
        hr = ma_IMMDevice_OpenPropertyStore(pMMDevice, STGM_READ, &pProperties);
        if (SUCCEEDED(hr)) {
            MA_PROPVARIANT var;

            ma_PropVariantInit(&var);
            hr = ma_IPropertyStore_GetValue(pProperties, &MA_PKEY_Device_FriendlyName, &var);
            if (SUCCEEDED(hr)) {
                WideCharToMultiByte(CP_UTF8, 0, var.pwszVal, -1, pInfo->name, sizeof(pInfo->name), 0, FALSE);
                ma_PropVariantClear(pContext, &var);
            }

            ma_IPropertyStore_Release(pProperties);
        }
    }

    /* Format */
    if (!onlySimpleInfo) {
        ma_IAudioClient* pAudioClient;
        hr = ma_IMMDevice_Activate(pMMDevice, &MA_IID_IAudioClient, CLSCTX_ALL, NULL, (void**)&pAudioClient);
        if (SUCCEEDED(hr)) {
            result = ma_context_get_device_info_from_IAudioClient__wasapi(pContext, pMMDevice, pAudioClient, pInfo);

            ma_IAudioClient_Release(pAudioClient);
            return result;
        } else {
            ma_log_postf(ma_context_get_log(pContext), MA_LOG_LEVEL_ERROR, "[WASAPI] Failed to activate audio client for device info retrieval.");
            return ma_result_from_HRESULT(hr);
        }
    }

    return MA_SUCCESS;
}

static ma_result ma_context_enumerate_devices_by_type__wasapi(ma_context* pContext, ma_IMMDeviceEnumerator* pDeviceEnumerator, ma_device_type deviceType, ma_enum_devices_callback_proc callback, void* pUserData)
{
    ma_result result = MA_SUCCESS;
    UINT deviceCount;
    HRESULT hr;
    ma_uint32 iDevice;
    WCHAR* pDefaultDeviceID = NULL;
    ma_IMMDeviceCollection* pDeviceCollection = NULL;

    MA_ASSERT(pContext != NULL);
    MA_ASSERT(callback != NULL);

    /* Grab the default device. We use this to know whether or not flag the returned device info as being the default. */
    pDefaultDeviceID = ma_context_get_default_device_id_from_IMMDeviceEnumerator__wasapi(pContext, pDeviceEnumerator, deviceType);

    /* We need to enumerate the devices which returns a device collection. */
    hr = ma_IMMDeviceEnumerator_EnumAudioEndpoints(pDeviceEnumerator, ma_device_type_to_EDataFlow(deviceType), MA_MM_DEVICE_STATE_ACTIVE, &pDeviceCollection);
    if (SUCCEEDED(hr)) {
        hr = ma_IMMDeviceCollection_GetCount(pDeviceCollection, &deviceCount);
        if (FAILED(hr)) {
            ma_log_postf(ma_context_get_log(pContext), MA_LOG_LEVEL_ERROR, "[WASAPI] Failed to get device count.\n");
            result = ma_result_from_HRESULT(hr);
            goto done;
        }

        for (iDevice = 0; iDevice < deviceCount; ++iDevice) {
            ma_device_info deviceInfo;
            ma_IMMDevice* pMMDevice;

            MA_ZERO_OBJECT(&deviceInfo);

            hr = ma_IMMDeviceCollection_Item(pDeviceCollection, iDevice, &pMMDevice);
            if (SUCCEEDED(hr)) {
                result = ma_context_get_device_info_from_MMDevice__wasapi(pContext, pMMDevice, pDefaultDeviceID, MA_TRUE, &deviceInfo);   /* MA_TRUE = onlySimpleInfo. */

                ma_IMMDevice_Release(pMMDevice);
                if (result == MA_SUCCESS) {
                    ma_bool32 cbResult = callback(pContext, deviceType, &deviceInfo, pUserData);
                    if (cbResult == MA_FALSE) {
                        break;
                    }
                }
            }
        }
    }

done:
    if (pDefaultDeviceID != NULL) {
        ma_CoTaskMemFree(pContext, pDefaultDeviceID);
        pDefaultDeviceID = NULL;
    }

    if (pDeviceCollection != NULL) {
        ma_IMMDeviceCollection_Release(pDeviceCollection);
        pDeviceCollection = NULL;
    }

    return result;
}

static ma_result ma_context_get_IAudioClient_Desktop__wasapi(ma_context* pContext, ma_device_type deviceType, const ma_device_id* pDeviceID, MA_PROPVARIANT* pActivationParams, ma_IAudioClient** ppAudioClient, ma_IMMDevice** ppMMDevice)
{
    ma_result result;
    HRESULT hr;

    MA_ASSERT(pContext != NULL);
    MA_ASSERT(ppAudioClient != NULL);
    MA_ASSERT(ppMMDevice != NULL);

    result = ma_context_get_MMDevice__wasapi(pContext, deviceType, pDeviceID, ppMMDevice);
    if (result != MA_SUCCESS) {
        return result;
    }

    hr = ma_IMMDevice_Activate(*ppMMDevice, &MA_IID_IAudioClient, CLSCTX_ALL, pActivationParams, (void**)ppAudioClient);
    if (FAILED(hr)) {
        return ma_result_from_HRESULT(hr);
    }

    return MA_SUCCESS;
}
#else
static ma_result ma_context_get_IAudioClient_UWP__wasapi(ma_context* pContext, ma_device_type deviceType, const ma_device_id* pDeviceID, MA_PROPVARIANT* pActivationParams, ma_IAudioClient** ppAudioClient, ma_IUnknown** ppActivatedInterface)
{
    ma_IActivateAudioInterfaceAsyncOperation *pAsyncOp = NULL;
    ma_completion_handler_uwp completionHandler;
    IID iid;
    WCHAR* iidStr;
    HRESULT hr;
    ma_result result;
    HRESULT activateResult;
    ma_IUnknown* pActivatedInterface;

    MA_ASSERT(pContext != NULL);
    MA_ASSERT(ppAudioClient != NULL);

    if (pDeviceID != NULL) {
        iidStr = (WCHAR*)pDeviceID->wasapi;
    } else {
        if (deviceType == ma_device_type_capture) {
            iid = MA_IID_DEVINTERFACE_AUDIO_CAPTURE;
        } else {
            iid = MA_IID_DEVINTERFACE_AUDIO_RENDER;
        }

    #if defined(__cplusplus)
        hr = StringFromIID(iid, &iidStr);
    #else
        hr = StringFromIID(&iid, &iidStr);
    #endif
        if (FAILED(hr)) {
            ma_log_postf(ma_context_get_log(pContext), MA_LOG_LEVEL_ERROR, "[WASAPI] Failed to convert device IID to string for ActivateAudioInterfaceAsync(). Out of memory.\n");
            return ma_result_from_HRESULT(hr);
        }
    }

    result = ma_completion_handler_uwp_init(&completionHandler);
    if (result != MA_SUCCESS) {
        ma_CoTaskMemFree(pContext, iidStr);
        ma_log_postf(ma_context_get_log(pContext), MA_LOG_LEVEL_ERROR, "[WASAPI] Failed to create event for waiting for ActivateAudioInterfaceAsync().\n");
        return result;
    }

    hr = ((MA_PFN_ActivateAudioInterfaceAsync)pContext->wasapi.ActivateAudioInterfaceAsync)(iidStr, &MA_IID_IAudioClient, pActivationParams, (ma_IActivateAudioInterfaceCompletionHandler*)&completionHandler, (ma_IActivateAudioInterfaceAsyncOperation**)&pAsyncOp);
    if (FAILED(hr)) {
        ma_completion_handler_uwp_uninit(&completionHandler);
        ma_CoTaskMemFree(pContext, iidStr);
        ma_log_postf(ma_context_get_log(pContext), MA_LOG_LEVEL_ERROR, "[WASAPI] ActivateAudioInterfaceAsync() failed.\n");
        return ma_result_from_HRESULT(hr);
    }

    if (pDeviceID == NULL) {
        ma_CoTaskMemFree(pContext, iidStr);
    }

    /* Wait for the async operation for finish. */
    ma_completion_handler_uwp_wait(&completionHandler);
    ma_completion_handler_uwp_uninit(&completionHandler);

    hr = ma_IActivateAudioInterfaceAsyncOperation_GetActivateResult(pAsyncOp, &activateResult, &pActivatedInterface);
    ma_IActivateAudioInterfaceAsyncOperation_Release(pAsyncOp);

    if (FAILED(hr) || FAILED(activateResult)) {
        ma_log_postf(ma_context_get_log(pContext), MA_LOG_LEVEL_ERROR, "[WASAPI] Failed to activate device.\n");
        return FAILED(hr) ? ma_result_from_HRESULT(hr) : ma_result_from_HRESULT(activateResult);
    }

    /* Here is where we grab the IAudioClient interface. */
    hr = ma_IUnknown_QueryInterface(pActivatedInterface, &MA_IID_IAudioClient, (void**)ppAudioClient);
    if (FAILED(hr)) {
        ma_log_postf(ma_context_get_log(pContext), MA_LOG_LEVEL_ERROR, "[WASAPI] Failed to query IAudioClient interface.\n");
        return ma_result_from_HRESULT(hr);
    }

    if (ppActivatedInterface) {
        *ppActivatedInterface = pActivatedInterface;
    } else {
        ma_IUnknown_Release(pActivatedInterface);
    }

    return MA_SUCCESS;
}
#endif


/* https://docs.microsoft.com/en-us/windows/win32/api/audioclientactivationparams/ne-audioclientactivationparams-audioclient_activation_type */
typedef enum
{
    MA_AUDIOCLIENT_ACTIVATION_TYPE_DEFAULT,
    MA_AUDIOCLIENT_ACTIVATION_TYPE_PROCESS_LOOPBACK
} MA_AUDIOCLIENT_ACTIVATION_TYPE;

/* https://docs.microsoft.com/en-us/windows/win32/api/audioclientactivationparams/ne-audioclientactivationparams-process_loopback_mode */
typedef enum
{
    MA_PROCESS_LOOPBACK_MODE_INCLUDE_TARGET_PROCESS_TREE,
    MA_PROCESS_LOOPBACK_MODE_EXCLUDE_TARGET_PROCESS_TREE
} MA_PROCESS_LOOPBACK_MODE;

/* https://docs.microsoft.com/en-us/windows/win32/api/audioclientactivationparams/ns-audioclientactivationparams-audioclient_process_loopback_params */
typedef struct
{
    DWORD TargetProcessId;
    MA_PROCESS_LOOPBACK_MODE ProcessLoopbackMode;
} MA_AUDIOCLIENT_PROCESS_LOOPBACK_PARAMS;

#if defined(_MSC_VER) && !defined(__clang__)
    #pragma warning(push)
    #pragma warning(disable:4201)   /* nonstandard extension used: nameless struct/union */
#elif defined(__clang__) || (defined(__GNUC__) && (__GNUC__ > 4 || (__GNUC__ == 4 && __GNUC_MINOR__ >= 8)))
    #pragma GCC diagnostic push
    #pragma GCC diagnostic ignored "-Wpedantic" /* For ISO C99 doesn't support unnamed structs/unions [-Wpedantic] */
    #if defined(__clang__)
        #pragma GCC diagnostic ignored "-Wc11-extensions"   /* anonymous unions are a C11 extension */
    #endif
#endif
/* https://docs.microsoft.com/en-us/windows/win32/api/audioclientactivationparams/ns-audioclientactivationparams-audioclient_activation_params */
typedef struct
{
    MA_AUDIOCLIENT_ACTIVATION_TYPE ActivationType;
    union
    {
        MA_AUDIOCLIENT_PROCESS_LOOPBACK_PARAMS ProcessLoopbackParams;
    };
} MA_AUDIOCLIENT_ACTIVATION_PARAMS;
#if defined(_MSC_VER) && !defined(__clang__)
    #pragma warning(pop)
#elif defined(__clang__) || (defined(__GNUC__) && (__GNUC__ > 4 || (__GNUC__ == 4 && __GNUC_MINOR__ >= 8)))
    #pragma GCC diagnostic pop
#endif

#define MA_VIRTUAL_AUDIO_DEVICE_PROCESS_LOOPBACK L"VAD\\Process_Loopback"

static ma_result ma_context_get_IAudioClient__wasapi(ma_context* pContext, ma_device_type deviceType, const ma_device_id* pDeviceID, ma_uint32 loopbackProcessID, ma_bool32 loopbackProcessExclude, ma_IAudioClient** ppAudioClient, ma_WASAPIDeviceInterface** ppDeviceInterface)
{
    ma_result result;
    ma_bool32 usingProcessLoopback = MA_FALSE;
    MA_AUDIOCLIENT_ACTIVATION_PARAMS audioclientActivationParams;
    MA_PROPVARIANT activationParams;
    MA_PROPVARIANT* pActivationParams = NULL;
    ma_device_id virtualDeviceID;

    /* Activation parameters specific to loopback mode. Note that process-specific loopback will only work when a default device ID is specified. */
    if (deviceType == ma_device_type_loopback && loopbackProcessID != 0 && pDeviceID == NULL) {
        usingProcessLoopback = MA_TRUE;
    }

    if (usingProcessLoopback) {
        MA_ZERO_OBJECT(&audioclientActivationParams);
        audioclientActivationParams.ActivationType                            = MA_AUDIOCLIENT_ACTIVATION_TYPE_PROCESS_LOOPBACK;
        audioclientActivationParams.ProcessLoopbackParams.ProcessLoopbackMode = (loopbackProcessExclude) ? MA_PROCESS_LOOPBACK_MODE_EXCLUDE_TARGET_PROCESS_TREE : MA_PROCESS_LOOPBACK_MODE_INCLUDE_TARGET_PROCESS_TREE;
        audioclientActivationParams.ProcessLoopbackParams.TargetProcessId     = (DWORD)loopbackProcessID;

        ma_PropVariantInit(&activationParams);
        activationParams.vt             = MA_VT_BLOB;
        activationParams.blob.cbSize    = sizeof(audioclientActivationParams);
        activationParams.blob.pBlobData = (BYTE*)&audioclientActivationParams;
        pActivationParams = &activationParams;

        /* When requesting a specific device ID we need to use a special device ID. */
        MA_COPY_MEMORY(virtualDeviceID.wasapi, MA_VIRTUAL_AUDIO_DEVICE_PROCESS_LOOPBACK, (wcslen(MA_VIRTUAL_AUDIO_DEVICE_PROCESS_LOOPBACK) + 1) * sizeof(wchar_t)); /* +1 for the null terminator. */
        pDeviceID = &virtualDeviceID;
    } else {
        pActivationParams = NULL;   /* No activation parameters required. */
    }

#if defined(MA_WIN32_DESKTOP) || defined(MA_WIN32_GDK)
    result = ma_context_get_IAudioClient_Desktop__wasapi(pContext, deviceType, pDeviceID, pActivationParams, ppAudioClient, ppDeviceInterface);
#else
    result = ma_context_get_IAudioClient_UWP__wasapi(pContext, deviceType, pDeviceID, pActivationParams, ppAudioClient, ppDeviceInterface);
#endif

    /*
    If loopback mode was requested with a process ID and initialization failed, it could be because it's
    trying to run on an older version of Windows where it's not supported. We need to let the caller
    know about this with a log message.
    */
    if (result != MA_SUCCESS) {
        if (usingProcessLoopback) {
            ma_log_postf(ma_context_get_log(pContext), MA_LOG_LEVEL_ERROR, "[WASAPI] Loopback mode requested to %s process ID %u, but initialization failed. Support for this feature begins with Windows 10 Build 20348. Confirm your version of Windows or consider not using process-specific loopback.\n", (loopbackProcessExclude) ? "exclude" : "include", loopbackProcessID);
        }
    }

    return result;
}


static ma_result ma_context_enumerate_devices__wasapi(ma_context* pContext, ma_enum_devices_callback_proc callback, void* pUserData)
{
    /* Different enumeration for desktop and UWP. */
#if defined(MA_WIN32_DESKTOP) || defined(MA_WIN32_GDK)
    /* Desktop */
    HRESULT hr;
    ma_IMMDeviceEnumerator* pDeviceEnumerator;

    hr = ma_CoCreateInstance(pContext, &MA_CLSID_MMDeviceEnumerator, NULL, CLSCTX_ALL, &MA_IID_IMMDeviceEnumerator, (void**)&pDeviceEnumerator);
    if (FAILED(hr)) {
        ma_log_postf(ma_context_get_log(pContext), MA_LOG_LEVEL_ERROR, "[WASAPI] Failed to create device enumerator.");
        return ma_result_from_HRESULT(hr);
    }

    ma_context_enumerate_devices_by_type__wasapi(pContext, pDeviceEnumerator, ma_device_type_playback, callback, pUserData);
    ma_context_enumerate_devices_by_type__wasapi(pContext, pDeviceEnumerator, ma_device_type_capture,  callback, pUserData);

    ma_IMMDeviceEnumerator_Release(pDeviceEnumerator);
#else
    /*
    UWP

    The MMDevice API is only supported on desktop applications. For now, while I'm still figuring out how to properly enumerate
    over devices without using MMDevice, I'm restricting devices to defaults.

    Hint: DeviceInformation::FindAllAsync() with DeviceClass.AudioCapture/AudioRender. https://blogs.windows.com/buildingapps/2014/05/15/real-time-audio-in-windows-store-and-windows-phone-apps/
    */
    if (callback) {
        ma_bool32 cbResult = MA_TRUE;

        /* Playback. */
        if (cbResult) {
            ma_device_info deviceInfo;
            MA_ZERO_OBJECT(&deviceInfo);
            ma_strncpy_s(deviceInfo.name, sizeof(deviceInfo.name), MA_DEFAULT_PLAYBACK_DEVICE_NAME, (size_t)-1);
            deviceInfo.isDefault = MA_TRUE;
            cbResult = callback(pContext, ma_device_type_playback, &deviceInfo, pUserData);
        }

        /* Capture. */
        if (cbResult) {
            ma_device_info deviceInfo;
            MA_ZERO_OBJECT(&deviceInfo);
            ma_strncpy_s(deviceInfo.name, sizeof(deviceInfo.name), MA_DEFAULT_CAPTURE_DEVICE_NAME, (size_t)-1);
            deviceInfo.isDefault = MA_TRUE;
            cbResult = callback(pContext, ma_device_type_capture, &deviceInfo, pUserData);
        }
    }
#endif

    return MA_SUCCESS;
}

static ma_result ma_context_get_device_info__wasapi(ma_context* pContext, ma_device_type deviceType, const ma_device_id* pDeviceID, ma_device_info* pDeviceInfo)
{
#if defined(MA_WIN32_DESKTOP) || defined(MA_WIN32_GDK)
    ma_result result;
    ma_IMMDevice* pMMDevice = NULL;
    WCHAR* pDefaultDeviceID = NULL;

    result = ma_context_get_MMDevice__wasapi(pContext, deviceType, pDeviceID, &pMMDevice);
    if (result != MA_SUCCESS) {
        return result;
    }

    /* We need the default device ID so we can set the isDefault flag in the device info. */
    pDefaultDeviceID = ma_context_get_default_device_id__wasapi(pContext, deviceType);

    result = ma_context_get_device_info_from_MMDevice__wasapi(pContext, pMMDevice, pDefaultDeviceID, MA_FALSE, pDeviceInfo);   /* MA_FALSE = !onlySimpleInfo. */

    if (pDefaultDeviceID != NULL) {
        ma_CoTaskMemFree(pContext, pDefaultDeviceID);
        pDefaultDeviceID = NULL;
    }

    ma_IMMDevice_Release(pMMDevice);

    return result;
#else
    ma_IAudioClient* pAudioClient;
    ma_result result;

    /* UWP currently only uses default devices. */
    if (deviceType == ma_device_type_playback) {
        ma_strncpy_s(pDeviceInfo->name, sizeof(pDeviceInfo->name), MA_DEFAULT_PLAYBACK_DEVICE_NAME, (size_t)-1);
    } else {
        ma_strncpy_s(pDeviceInfo->name, sizeof(pDeviceInfo->name), MA_DEFAULT_CAPTURE_DEVICE_NAME, (size_t)-1);
    }

    result = ma_context_get_IAudioClient_UWP__wasapi(pContext, deviceType, pDeviceID, NULL, &pAudioClient, NULL);
    if (result != MA_SUCCESS) {
        return result;
    }

    result = ma_context_get_device_info_from_IAudioClient__wasapi(pContext, NULL, pAudioClient, pDeviceInfo);

    pDeviceInfo->isDefault = MA_TRUE;  /* UWP only supports default devices. */

    ma_IAudioClient_Release(pAudioClient);
    return result;
#endif
}

static ma_result ma_device_uninit__wasapi(ma_device* pDevice)
{
    MA_ASSERT(pDevice != NULL);

#if defined(MA_WIN32_DESKTOP) || defined(MA_WIN32_GDK)
    if (pDevice->wasapi.pDeviceEnumerator) {
        ((ma_IMMDeviceEnumerator*)pDevice->wasapi.pDeviceEnumerator)->lpVtbl->UnregisterEndpointNotificationCallback((ma_IMMDeviceEnumerator*)pDevice->wasapi.pDeviceEnumerator, &pDevice->wasapi.notificationClient);
        ma_IMMDeviceEnumerator_Release((ma_IMMDeviceEnumerator*)pDevice->wasapi.pDeviceEnumerator);
    }
#endif

    if (pDevice->wasapi.pRenderClient) {
        if (pDevice->wasapi.pMappedBufferPlayback != NULL) {
            ma_IAudioRenderClient_ReleaseBuffer((ma_IAudioRenderClient*)pDevice->wasapi.pRenderClient, pDevice->wasapi.mappedBufferPlaybackCap, 0);
            pDevice->wasapi.pMappedBufferPlayback   = NULL;
            pDevice->wasapi.mappedBufferPlaybackCap = 0;
            pDevice->wasapi.mappedBufferPlaybackLen = 0;
        }

        ma_IAudioRenderClient_Release((ma_IAudioRenderClient*)pDevice->wasapi.pRenderClient);
    }
    if (pDevice->wasapi.pCaptureClient) {
        if (pDevice->wasapi.pMappedBufferCapture != NULL) {
            ma_IAudioCaptureClient_ReleaseBuffer((ma_IAudioCaptureClient*)pDevice->wasapi.pCaptureClient, pDevice->wasapi.mappedBufferCaptureCap);
            pDevice->wasapi.pMappedBufferCapture   = NULL;
            pDevice->wasapi.mappedBufferCaptureCap = 0;
            pDevice->wasapi.mappedBufferCaptureLen = 0;
        }

        ma_IAudioCaptureClient_Release((ma_IAudioCaptureClient*)pDevice->wasapi.pCaptureClient);
    }

    if (pDevice->wasapi.pAudioClientPlayback) {
        ma_IAudioClient_Release((ma_IAudioClient*)pDevice->wasapi.pAudioClientPlayback);
    }
    if (pDevice->wasapi.pAudioClientCapture) {
        ma_IAudioClient_Release((ma_IAudioClient*)pDevice->wasapi.pAudioClientCapture);
    }

    if (pDevice->wasapi.hEventPlayback) {
        CloseHandle((HANDLE)pDevice->wasapi.hEventPlayback);
    }
    if (pDevice->wasapi.hEventCapture) {
        CloseHandle((HANDLE)pDevice->wasapi.hEventCapture);
    }

    return MA_SUCCESS;
}


typedef struct
{
    /* Input. */
    ma_format formatIn;
    ma_uint32 channelsIn;
    ma_uint32 sampleRateIn;
    ma_channel channelMapIn[MA_MAX_CHANNELS];
    ma_uint32 periodSizeInFramesIn;
    ma_uint32 periodSizeInMillisecondsIn;
    ma_uint32 periodsIn;
    ma_share_mode shareMode;
    ma_performance_profile performanceProfile;
    ma_bool32 noAutoConvertSRC;
    ma_bool32 noDefaultQualitySRC;
    ma_bool32 noHardwareOffloading;
    ma_uint32 loopbackProcessID;
    ma_bool32 loopbackProcessExclude;

    /* Output. */
    ma_IAudioClient* pAudioClient;
    ma_IAudioRenderClient* pRenderClient;
    ma_IAudioCaptureClient* pCaptureClient;
    ma_format formatOut;
    ma_uint32 channelsOut;
    ma_uint32 sampleRateOut;
    ma_channel channelMapOut[MA_MAX_CHANNELS];
    ma_uint32 periodSizeInFramesOut;
    ma_uint32 periodsOut;
    ma_bool32 usingAudioClient3;
    char deviceName[256];
    ma_device_id id;
} ma_device_init_internal_data__wasapi;

static ma_result ma_device_init_internal__wasapi(ma_context* pContext, ma_device_type deviceType, const ma_device_id* pDeviceID, ma_device_init_internal_data__wasapi* pData)
{
    HRESULT hr;
    ma_result result = MA_SUCCESS;
    const char* errorMsg = "";
    MA_AUDCLNT_SHAREMODE shareMode = MA_AUDCLNT_SHAREMODE_SHARED;
    DWORD streamFlags = 0;
    MA_REFERENCE_TIME periodDurationInMicroseconds;
    ma_bool32 wasInitializedUsingIAudioClient3 = MA_FALSE;
    MA_WAVEFORMATEXTENSIBLE wf;
    ma_WASAPIDeviceInterface* pDeviceInterface = NULL;
    ma_IAudioClient2* pAudioClient2;
    ma_uint32 nativeSampleRate;
    ma_bool32 usingProcessLoopback = MA_FALSE;

    MA_ASSERT(pContext != NULL);
    MA_ASSERT(pData != NULL);

    /* This function is only used to initialize one device type: either playback, capture or loopback. Never full-duplex. */
    if (deviceType == ma_device_type_duplex) {
        return MA_INVALID_ARGS;
    }

    usingProcessLoopback = deviceType == ma_device_type_loopback && pData->loopbackProcessID != 0 && pDeviceID == NULL;

    pData->pAudioClient = NULL;
    pData->pRenderClient = NULL;
    pData->pCaptureClient = NULL;

    streamFlags = MA_AUDCLNT_STREAMFLAGS_EVENTCALLBACK;
    if (!pData->noAutoConvertSRC && pData->sampleRateIn != 0 && pData->shareMode != ma_share_mode_exclusive) {    /* <-- Exclusive streams must use the native sample rate. */
        streamFlags |= MA_AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM;
    }
    if (!pData->noDefaultQualitySRC && pData->sampleRateIn != 0 && (streamFlags & MA_AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM) != 0) {
        streamFlags |= MA_AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY;
    }
    if (deviceType == ma_device_type_loopback) {
        streamFlags |= MA_AUDCLNT_STREAMFLAGS_LOOPBACK;
    }

    result = ma_context_get_IAudioClient__wasapi(pContext, deviceType, pDeviceID, pData->loopbackProcessID, pData->loopbackProcessExclude, &pData->pAudioClient, &pDeviceInterface);
    if (result != MA_SUCCESS) {
        goto done;
    }

    MA_ZERO_OBJECT(&wf);

    /* Try enabling hardware offloading. */
    if (!pData->noHardwareOffloading) {
        hr = ma_IAudioClient_QueryInterface(pData->pAudioClient, &MA_IID_IAudioClient2, (void**)&pAudioClient2);
        if (SUCCEEDED(hr)) {
            BOOL isHardwareOffloadingSupported = 0;
            hr = ma_IAudioClient2_IsOffloadCapable(pAudioClient2, MA_AudioCategory_Other, &isHardwareOffloadingSupported);
            if (SUCCEEDED(hr) && isHardwareOffloadingSupported) {
                ma_AudioClientProperties clientProperties;
                MA_ZERO_OBJECT(&clientProperties);
                clientProperties.cbSize = sizeof(clientProperties);
                clientProperties.bIsOffload = 1;
                clientProperties.eCategory = MA_AudioCategory_Other;
                ma_IAudioClient2_SetClientProperties(pAudioClient2, &clientProperties);
            }

            pAudioClient2->lpVtbl->Release(pAudioClient2);
        }
    }

    /* Here is where we try to determine the best format to use with the device. If the client if wanting exclusive mode, first try finding the best format for that. If this fails, fall back to shared mode. */
    result = MA_FORMAT_NOT_SUPPORTED;
    if (pData->shareMode == ma_share_mode_exclusive) {
    #if defined(MA_WIN32_DESKTOP) || defined(MA_WIN32_GDK)
        /* In exclusive mode on desktop we always use the backend's native format. */
        ma_IPropertyStore* pStore = NULL;
        hr = ma_IMMDevice_OpenPropertyStore(pDeviceInterface, STGM_READ, &pStore);
        if (SUCCEEDED(hr)) {
            MA_PROPVARIANT prop;
            ma_PropVariantInit(&prop);
            hr = ma_IPropertyStore_GetValue(pStore, &MA_PKEY_AudioEngine_DeviceFormat, &prop);
            if (SUCCEEDED(hr)) {
                MA_WAVEFORMATEX* pActualFormat = (MA_WAVEFORMATEX*)prop.blob.pBlobData;
                hr = ma_IAudioClient_IsFormatSupported((ma_IAudioClient*)pData->pAudioClient, MA_AUDCLNT_SHAREMODE_EXCLUSIVE, pActualFormat, NULL);
                if (SUCCEEDED(hr)) {
                    MA_COPY_MEMORY(&wf, pActualFormat, sizeof(MA_WAVEFORMATEXTENSIBLE));
                }

                ma_PropVariantClear(pContext, &prop);
            }

            ma_IPropertyStore_Release(pStore);
        }
    #else
        /*
        I do not know how to query the device's native format on UWP so for now I'm just disabling support for
        exclusive mode. The alternative is to enumerate over different formats and check IsFormatSupported()
        until you find one that works.

        TODO: Add support for exclusive mode to UWP.
        */
        hr = S_FALSE;
    #endif

        if (hr == S_OK) {
            shareMode = MA_AUDCLNT_SHAREMODE_EXCLUSIVE;
            result = MA_SUCCESS;
        } else {
            result = MA_SHARE_MODE_NOT_SUPPORTED;
        }
    } else {
        /* In shared mode we are always using the format reported by the operating system. */
        MA_WAVEFORMATEXTENSIBLE* pNativeFormat = NULL;
        hr = ma_IAudioClient_GetMixFormat((ma_IAudioClient*)pData->pAudioClient, (MA_WAVEFORMATEX**)&pNativeFormat);
        if (hr != S_OK) {
            /* When using process-specific loopback, GetMixFormat() seems to always fail. */
            if (usingProcessLoopback) {
                wf.wFormatTag      = WAVE_FORMAT_IEEE_FLOAT;
                wf.nChannels       = 2;
                wf.nSamplesPerSec  = 44100;
                wf.wBitsPerSample  = 32;
                wf.nBlockAlign     = wf.nChannels * wf.wBitsPerSample / 8;
                wf.nAvgBytesPerSec = wf.nSamplesPerSec * wf.nBlockAlign;
                wf.cbSize          = sizeof(MA_WAVEFORMATEX);

                result = MA_SUCCESS;
            } else {
                result = MA_FORMAT_NOT_SUPPORTED;
            }
        } else {
            /*
            I've seen cases where cbSize will be set to sizeof(WAVEFORMATEX) even though the structure itself
            is given the format tag of WAVE_FORMAT_EXTENSIBLE. If the format tag is WAVE_FORMAT_EXTENSIBLE
            want to make sure we copy the whole WAVEFORMATEXTENSIBLE structure. Otherwise we'll have to be
            safe and only copy the WAVEFORMATEX part.
            */
            if (pNativeFormat->wFormatTag == WAVE_FORMAT_EXTENSIBLE) {
                MA_COPY_MEMORY(&wf, pNativeFormat, sizeof(MA_WAVEFORMATEXTENSIBLE));
            } else {
                /* I've seen a case where cbSize was set to 0. Assume sizeof(WAVEFORMATEX) in this case. */
                size_t cbSize = pNativeFormat->cbSize;
                if (cbSize == 0) {
                    cbSize = sizeof(MA_WAVEFORMATEX);
                }

                /* Make sure we don't copy more than the capacity of `wf`. */
                if (cbSize > sizeof(wf)) {
                    cbSize = sizeof(wf);
                }

                MA_COPY_MEMORY(&wf, pNativeFormat, cbSize);
            }

            result = MA_SUCCESS;
        }

        ma_CoTaskMemFree(pContext, pNativeFormat);

        shareMode = MA_AUDCLNT_SHAREMODE_SHARED;
    }

    /* Return an error if we still haven't found a format. */
    if (result != MA_SUCCESS) {
        errorMsg = "[WASAPI] Failed to find best device mix format.";
        goto done;
    }

    /*
    Override the native sample rate with the one requested by the caller, but only if we're not using the default sample rate. We'll use
    WASAPI to perform the sample rate conversion.
    */
    nativeSampleRate = wf.nSamplesPerSec;
    if (streamFlags & MA_AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM) {
        wf.nSamplesPerSec = (pData->sampleRateIn != 0) ? pData->sampleRateIn : MA_DEFAULT_SAMPLE_RATE;
        wf.nAvgBytesPerSec = wf.nSamplesPerSec * wf.nBlockAlign;
    }

    pData->formatOut = ma_format_from_WAVEFORMATEX((MA_WAVEFORMATEX*)&wf);
    if (pData->formatOut == ma_format_unknown) {
        /*
        The format isn't supported. This is almost certainly because the exclusive mode format isn't supported by miniaudio. We need to return MA_SHARE_MODE_NOT_SUPPORTED
        in this case so that the caller can detect it and fall back to shared mode if desired. We should never get here if shared mode was requested, but just for
        completeness we'll check for it and return MA_FORMAT_NOT_SUPPORTED.
        */
        if (shareMode == MA_AUDCLNT_SHAREMODE_EXCLUSIVE) {
            result = MA_SHARE_MODE_NOT_SUPPORTED;
        } else {
            result = MA_FORMAT_NOT_SUPPORTED;
        }

        errorMsg = "[WASAPI] Native format not supported.";
        goto done;
    }

    pData->channelsOut = wf.nChannels;
    pData->sampleRateOut = wf.nSamplesPerSec;

    /*
    Get the internal channel map based on the channel mask. There is a possibility that GetMixFormat() returns
    a WAVEFORMATEX instead of a WAVEFORMATEXTENSIBLE, in which case the channel mask will be undefined. In this
    case we'll just use the default channel map.
    */
    if (wf.wFormatTag == WAVE_FORMAT_EXTENSIBLE || wf.cbSize >= sizeof(MA_WAVEFORMATEXTENSIBLE)) {
        ma_channel_mask_to_channel_map__win32(wf.dwChannelMask, pData->channelsOut, pData->channelMapOut);
    } else {
        ma_channel_map_init_standard(ma_standard_channel_map_microsoft, pData->channelMapOut, ma_countof(pData->channelMapOut), pData->channelsOut);
    }

    /* Period size. */
    pData->periodsOut = (pData->periodsIn != 0) ? pData->periodsIn : MA_DEFAULT_PERIODS;
    pData->periodSizeInFramesOut = pData->periodSizeInFramesIn;
    if (pData->periodSizeInFramesOut == 0) {
        if (pData->periodSizeInMillisecondsIn == 0) {
            if (pData->performanceProfile == ma_performance_profile_low_latency) {
                pData->periodSizeInFramesOut = ma_calculate_buffer_size_in_frames_from_milliseconds(MA_DEFAULT_PERIOD_SIZE_IN_MILLISECONDS_LOW_LATENCY, wf.nSamplesPerSec);
            } else {
                pData->periodSizeInFramesOut = ma_calculate_buffer_size_in_frames_from_milliseconds(MA_DEFAULT_PERIOD_SIZE_IN_MILLISECONDS_CONSERVATIVE, wf.nSamplesPerSec);
            }
        } else {
            pData->periodSizeInFramesOut = ma_calculate_buffer_size_in_frames_from_milliseconds(pData->periodSizeInMillisecondsIn, wf.nSamplesPerSec);
        }
    }

    periodDurationInMicroseconds = ((ma_uint64)pData->periodSizeInFramesOut * 1000 * 1000) / wf.nSamplesPerSec;


    /* Slightly different initialization for shared and exclusive modes. We try exclusive mode first, and if it fails, fall back to shared mode. */
    if (shareMode == MA_AUDCLNT_SHAREMODE_EXCLUSIVE) {
        MA_REFERENCE_TIME bufferDuration = periodDurationInMicroseconds * pData->periodsOut * 10;

        /*
        If the periodicy is too small, Initialize() will fail with AUDCLNT_E_INVALID_DEVICE_PERIOD. In this case we should just keep increasing
        it and trying it again.
        */
        hr = E_FAIL;
        for (;;) {
            hr = ma_IAudioClient_Initialize((ma_IAudioClient*)pData->pAudioClient, shareMode, streamFlags, bufferDuration, bufferDuration, (MA_WAVEFORMATEX*)&wf, NULL);
            if (hr == MA_AUDCLNT_E_INVALID_DEVICE_PERIOD) {
                if (bufferDuration > 500*10000) {
                    break;
                } else {
                    if (bufferDuration == 0) {  /* <-- Just a sanity check to prevent an infinit loop. Should never happen, but it makes me feel better. */
                        break;
                    }

                    bufferDuration = bufferDuration * 2;
                    continue;
                }
            } else {
                break;
            }
        }

        if (hr == MA_AUDCLNT_E_BUFFER_SIZE_NOT_ALIGNED) {
            ma_uint32 bufferSizeInFrames;
            hr = ma_IAudioClient_GetBufferSize((ma_IAudioClient*)pData->pAudioClient, &bufferSizeInFrames);
            if (SUCCEEDED(hr)) {
                bufferDuration = (MA_REFERENCE_TIME)((10000.0 * 1000 / wf.nSamplesPerSec * bufferSizeInFrames) + 0.5);

                /* Unfortunately we need to release and re-acquire the audio client according to MSDN. Seems silly - why not just call IAudioClient_Initialize() again?! */
                ma_IAudioClient_Release((ma_IAudioClient*)pData->pAudioClient);

            #if defined(MA_WIN32_DESKTOP) || defined(MA_WIN32_GDK)
                hr = ma_IMMDevice_Activate(pDeviceInterface, &MA_IID_IAudioClient, CLSCTX_ALL, NULL, (void**)&pData->pAudioClient);
            #else
                hr = ma_IUnknown_QueryInterface(pDeviceInterface, &MA_IID_IAudioClient, (void**)&pData->pAudioClient);
            #endif

                if (SUCCEEDED(hr)) {
                    hr = ma_IAudioClient_Initialize((ma_IAudioClient*)pData->pAudioClient, shareMode, streamFlags, bufferDuration, bufferDuration, (MA_WAVEFORMATEX*)&wf, NULL);
                }
            }
        }

        if (FAILED(hr)) {
            /* Failed to initialize in exclusive mode. Don't fall back to shared mode - instead tell the client about it. They can reinitialize in shared mode if they want. */
            if (hr == E_ACCESSDENIED) {
                errorMsg = "[WASAPI] Failed to initialize device in exclusive mode. Access denied.", result = MA_ACCESS_DENIED;
            } else if (hr == MA_AUDCLNT_E_DEVICE_IN_USE) {
                errorMsg = "[WASAPI] Failed to initialize device in exclusive mode. Device in use.", result = MA_BUSY;
            } else {
                errorMsg = "[WASAPI] Failed to initialize device in exclusive mode."; result = ma_result_from_HRESULT(hr);
            }
            goto done;
        }
    }

    if (shareMode == MA_AUDCLNT_SHAREMODE_SHARED) {
        /*
        Low latency shared mode via IAudioClient3.

        NOTE
        ====
        Contrary to the documentation on MSDN (https://docs.microsoft.com/en-us/windows/win32/api/audioclient/nf-audioclient-iaudioclient3-initializesharedaudiostream), the
        use of AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM and AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY with IAudioClient3_InitializeSharedAudioStream() absolutely does not work. Using
        any of these flags will result in HRESULT code 0x88890021. The other problem is that calling IAudioClient3_GetSharedModeEnginePeriod() with a sample rate different to
        that returned by IAudioClient_GetMixFormat() also results in an error. I'm therefore disabling low-latency shared mode with AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM.
        */
        #ifndef MA_WASAPI_NO_LOW_LATENCY_SHARED_MODE
        {
            if ((streamFlags & MA_AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM) == 0 || nativeSampleRate == wf.nSamplesPerSec) {
                ma_IAudioClient3* pAudioClient3 = NULL;
                hr = ma_IAudioClient_QueryInterface(pData->pAudioClient, &MA_IID_IAudioClient3, (void**)&pAudioClient3);
                if (SUCCEEDED(hr)) {
                    ma_uint32 defaultPeriodInFrames;
                    ma_uint32 fundamentalPeriodInFrames;
                    ma_uint32 minPeriodInFrames;
                    ma_uint32 maxPeriodInFrames;
                    hr = ma_IAudioClient3_GetSharedModeEnginePeriod(pAudioClient3, (MA_WAVEFORMATEX*)&wf, &defaultPeriodInFrames, &fundamentalPeriodInFrames, &minPeriodInFrames, &maxPeriodInFrames);
                    if (SUCCEEDED(hr)) {
                        ma_uint32 desiredPeriodInFrames = pData->periodSizeInFramesOut;
                        ma_uint32 actualPeriodInFrames  = desiredPeriodInFrames;

                        /* Make sure the period size is a multiple of fundamentalPeriodInFrames. */
                        actualPeriodInFrames = actualPeriodInFrames / fundamentalPeriodInFrames;
                        actualPeriodInFrames = actualPeriodInFrames * fundamentalPeriodInFrames;

                        /* The period needs to be clamped between minPeriodInFrames and maxPeriodInFrames. */
                        actualPeriodInFrames = ma_clamp(actualPeriodInFrames, minPeriodInFrames, maxPeriodInFrames);

                        ma_log_postf(ma_context_get_log(pContext), MA_LOG_LEVEL_DEBUG, "[WASAPI] Trying IAudioClient3_InitializeSharedAudioStream(actualPeriodInFrames=%d)\n", actualPeriodInFrames);
                        ma_log_postf(ma_context_get_log(pContext), MA_LOG_LEVEL_DEBUG, "    defaultPeriodInFrames=%d\n", defaultPeriodInFrames);
                        ma_log_postf(ma_context_get_log(pContext), MA_LOG_LEVEL_DEBUG, "    fundamentalPeriodInFrames=%d\n", fundamentalPeriodInFrames);
                        ma_log_postf(ma_context_get_log(pContext), MA_LOG_LEVEL_DEBUG, "    minPeriodInFrames=%d\n", minPeriodInFrames);
                        ma_log_postf(ma_context_get_log(pContext), MA_LOG_LEVEL_DEBUG, "    maxPeriodInFrames=%d\n", maxPeriodInFrames);

                        /* If the client requested a largish buffer than we don't actually want to use low latency shared mode because it forces small buffers. */
                        if (actualPeriodInFrames >= desiredPeriodInFrames) {
                            /*
                            MA_AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM | MA_AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY must not be in the stream flags. If either of these are specified,
                            IAudioClient3_InitializeSharedAudioStream() will fail.
                            */
                            hr = ma_IAudioClient3_InitializeSharedAudioStream(pAudioClient3, streamFlags & ~(MA_AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM | MA_AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY), actualPeriodInFrames, (MA_WAVEFORMATEX*)&wf, NULL);
                            if (SUCCEEDED(hr)) {
                                wasInitializedUsingIAudioClient3 = MA_TRUE;
                                pData->periodSizeInFramesOut = actualPeriodInFrames;

                                ma_log_postf(ma_context_get_log(pContext), MA_LOG_LEVEL_DEBUG, "[WASAPI] Using IAudioClient3\n");
                                ma_log_postf(ma_context_get_log(pContext), MA_LOG_LEVEL_DEBUG, "    periodSizeInFramesOut=%d\n", pData->periodSizeInFramesOut);
                            } else {
                                ma_log_postf(ma_context_get_log(pContext), MA_LOG_LEVEL_DEBUG, "[WASAPI] IAudioClient3_InitializeSharedAudioStream failed. Falling back to IAudioClient.\n");
                            }
                        } else {
                            ma_log_postf(ma_context_get_log(pContext), MA_LOG_LEVEL_DEBUG, "[WASAPI] Not using IAudioClient3 because the desired period size is larger than the maximum supported by IAudioClient3.\n");
                        }
                    } else {
                        ma_log_postf(ma_context_get_log(pContext), MA_LOG_LEVEL_DEBUG, "[WASAPI] IAudioClient3_GetSharedModeEnginePeriod failed. Falling back to IAudioClient.\n");
                    }

                    ma_IAudioClient3_Release(pAudioClient3);
                    pAudioClient3 = NULL;
                }
            }
        }
        #else
        {
            ma_log_postf(ma_context_get_log(pContext), MA_LOG_LEVEL_DEBUG, "[WASAPI] Not using IAudioClient3 because MA_WASAPI_NO_LOW_LATENCY_SHARED_MODE is enabled.\n");
        }
        #endif

        /* If we don't have an IAudioClient3 then we need to use the normal initialization routine. */
        if (!wasInitializedUsingIAudioClient3) {
            MA_REFERENCE_TIME bufferDuration = periodDurationInMicroseconds * pData->periodsOut * 10;   /* <-- Multiply by 10 for microseconds to 100-nanoseconds. */
            hr = ma_IAudioClient_Initialize((ma_IAudioClient*)pData->pAudioClient, shareMode, streamFlags, bufferDuration, 0, (const MA_WAVEFORMATEX*)&wf, NULL);
            if (FAILED(hr)) {
                if (hr == E_ACCESSDENIED) {
                    errorMsg = "[WASAPI] Failed to initialize device. Access denied.", result = MA_ACCESS_DENIED;
                } else if (hr == MA_AUDCLNT_E_DEVICE_IN_USE) {
                    errorMsg = "[WASAPI] Failed to initialize device. Device in use.", result = MA_BUSY;
                } else {
                    errorMsg = "[WASAPI] Failed to initialize device.", result = ma_result_from_HRESULT(hr);
                }

                goto done;
            }
        }
    }

    if (!wasInitializedUsingIAudioClient3) {
        ma_uint32 bufferSizeInFrames = 0;
        hr = ma_IAudioClient_GetBufferSize((ma_IAudioClient*)pData->pAudioClient, &bufferSizeInFrames);
        if (FAILED(hr)) {
            errorMsg = "[WASAPI] Failed to get audio client's actual buffer size.", result = ma_result_from_HRESULT(hr);
            goto done;
        }

        /*
        When using process loopback mode, retrieval of the buffer size seems to result in totally
        incorrect values. In this case we'll just assume it's the same size as what we requested
        when we initialized the client.
        */
        if (usingProcessLoopback) {
            bufferSizeInFrames = (ma_uint32)((periodDurationInMicroseconds * pData->periodsOut) * pData->sampleRateOut / 1000000);
        }

        pData->periodSizeInFramesOut = bufferSizeInFrames / pData->periodsOut;
    }

    pData->usingAudioClient3 = wasInitializedUsingIAudioClient3;


    if (deviceType == ma_device_type_playback) {
        result = ma_device_create_IAudioClient_service__wasapi(pContext, deviceType, (ma_IAudioClient*)pData->pAudioClient, (void**)&pData->pRenderClient);
    } else {
        result = ma_device_create_IAudioClient_service__wasapi(pContext, deviceType, (ma_IAudioClient*)pData->pAudioClient, (void**)&pData->pCaptureClient);
    }

    /*if (FAILED(hr)) {*/
    if (result != MA_SUCCESS) {
        errorMsg = "[WASAPI] Failed to get audio client service.";
        goto done;
    }


    /* Grab the name of the device. */
    #if defined(MA_WIN32_DESKTOP) || defined(MA_WIN32_GDK)
    {
        ma_IPropertyStore *pProperties;
        hr = ma_IMMDevice_OpenPropertyStore(pDeviceInterface, STGM_READ, &pProperties);
        if (SUCCEEDED(hr)) {
            MA_PROPVARIANT varName;
            ma_PropVariantInit(&varName);
            hr = ma_IPropertyStore_GetValue(pProperties, &MA_PKEY_Device_FriendlyName, &varName);
            if (SUCCEEDED(hr)) {
                WideCharToMultiByte(CP_UTF8, 0, varName.pwszVal, -1, pData->deviceName, sizeof(pData->deviceName), 0, FALSE);
                ma_PropVariantClear(pContext, &varName);
            }

            ma_IPropertyStore_Release(pProperties);
        }
    }
    #endif

    /*
    For the WASAPI backend we need to know the actual IDs of the device in order to do automatic
    stream routing so that IDs can be compared and we can determine which device has been detached
    and whether or not it matches with our ma_device.
    */
    #if defined(MA_WIN32_DESKTOP) || defined(MA_WIN32_GDK)
    {
        /* Desktop */
        ma_context_get_device_id_from_MMDevice__wasapi(pContext, pDeviceInterface, &pData->id);
    }
    #else
    {
        /* UWP */
        /* TODO: Implement me. Need to figure out how to get the ID of the default device. */
    }
    #endif

done:
    /* Clean up. */
#if defined(MA_WIN32_DESKTOP) || defined(MA_WIN32_GDK)
    if (pDeviceInterface != NULL) {
        ma_IMMDevice_Release(pDeviceInterface);
    }
#else
    if (pDeviceInterface != NULL) {
        ma_IUnknown_Release(pDeviceInterface);
    }
#endif

    if (result != MA_SUCCESS) {
        if (pData->pRenderClient) {
            ma_IAudioRenderClient_Release((ma_IAudioRenderClient*)pData->pRenderClient);
            pData->pRenderClient = NULL;
        }
        if (pData->pCaptureClient) {
            ma_IAudioCaptureClient_Release((ma_IAudioCaptureClient*)pData->pCaptureClient);
            pData->pCaptureClient = NULL;
        }
        if (pData->pAudioClient) {
            ma_IAudioClient_Release((ma_IAudioClient*)pData->pAudioClient);
            pData->pAudioClient = NULL;
        }

        if (errorMsg != NULL && errorMsg[0] != '\0') {
            ma_log_postf(ma_context_get_log(pContext), MA_LOG_LEVEL_ERROR, "%s\n", errorMsg);
        }

        return result;
    } else {
        return MA_SUCCESS;
    }
}

static ma_result ma_device_reinit__wasapi(ma_device* pDevice, ma_device_type deviceType)
{
    ma_device_init_internal_data__wasapi data;
    ma_result result;

    MA_ASSERT(pDevice != NULL);

    /* We only re-initialize the playback or capture device. Never a full-duplex device. */
    if (deviceType == ma_device_type_duplex) {
        return MA_INVALID_ARGS;
    }


    /*
    Before reinitializing the device we need to free the previous audio clients.

    There's a known memory leak here. We will be calling this from the routing change callback that
    is fired by WASAPI. If we attempt to release the IAudioClient we will deadlock. In my opinion
    this is a bug. I'm not sure what I need to do to handle this cleanly, but I think we'll probably
    need some system where we post an event, but delay the execution of it until the callback has
    returned. I'm not sure how to do this reliably, however. I have set up some infrastructure for
    a command thread which might be useful for this.
    */
    if (deviceType == ma_device_type_capture || deviceType == ma_device_type_loopback) {
        if (pDevice->wasapi.pCaptureClient) {
            ma_IAudioCaptureClient_Release((ma_IAudioCaptureClient*)pDevice->wasapi.pCaptureClient);
            pDevice->wasapi.pCaptureClient = NULL;
        }

        if (pDevice->wasapi.pAudioClientCapture) {
            /*ma_device_release_IAudioClient_service__wasapi(pDevice, ma_device_type_capture);*/
            pDevice->wasapi.pAudioClientCapture = NULL;
        }
    }

    if (deviceType == ma_device_type_playback) {
        if (pDevice->wasapi.pRenderClient) {
            ma_IAudioRenderClient_Release((ma_IAudioRenderClient*)pDevice->wasapi.pRenderClient);
            pDevice->wasapi.pRenderClient = NULL;
        }

        if (pDevice->wasapi.pAudioClientPlayback) {
            /*ma_device_release_IAudioClient_service__wasapi(pDevice, ma_device_type_playback);*/
            pDevice->wasapi.pAudioClientPlayback = NULL;
        }
    }


    if (deviceType == ma_device_type_playback) {
        data.formatIn               = pDevice->playback.format;
        data.channelsIn             = pDevice->playback.channels;
        MA_COPY_MEMORY(data.channelMapIn, pDevice->playback.channelMap, sizeof(pDevice->playback.channelMap));
        data.shareMode              = pDevice->playback.shareMode;
    } else {
        data.formatIn               = pDevice->capture.format;
        data.channelsIn             = pDevice->capture.channels;
        MA_COPY_MEMORY(data.channelMapIn, pDevice->capture.channelMap, sizeof(pDevice->capture.channelMap));
        data.shareMode              = pDevice->capture.shareMode;
    }

    data.sampleRateIn               = pDevice->sampleRate;
    data.periodSizeInFramesIn       = pDevice->wasapi.originalPeriodSizeInFrames;
    data.periodSizeInMillisecondsIn = pDevice->wasapi.originalPeriodSizeInMilliseconds;
    data.periodsIn                  = pDevice->wasapi.originalPeriods;
    data.performanceProfile         = pDevice->wasapi.originalPerformanceProfile;
    data.noAutoConvertSRC           = pDevice->wasapi.noAutoConvertSRC;
    data.noDefaultQualitySRC        = pDevice->wasapi.noDefaultQualitySRC;
    data.noHardwareOffloading       = pDevice->wasapi.noHardwareOffloading;
    data.loopbackProcessID          = pDevice->wasapi.loopbackProcessID;
    data.loopbackProcessExclude     = pDevice->wasapi.loopbackProcessExclude;
    result = ma_device_init_internal__wasapi(pDevice->pContext, deviceType, NULL, &data);
    if (result != MA_SUCCESS) {
        return result;
    }

    /* At this point we have some new objects ready to go. We need to uninitialize the previous ones and then set the new ones. */
    if (deviceType == ma_device_type_capture || deviceType == ma_device_type_loopback) {
        pDevice->wasapi.pAudioClientCapture         = data.pAudioClient;
        pDevice->wasapi.pCaptureClient              = data.pCaptureClient;

        pDevice->capture.internalFormat             = data.formatOut;
        pDevice->capture.internalChannels           = data.channelsOut;
        pDevice->capture.internalSampleRate         = data.sampleRateOut;
        MA_COPY_MEMORY(pDevice->capture.internalChannelMap, data.channelMapOut, sizeof(data.channelMapOut));
        pDevice->capture.internalPeriodSizeInFrames = data.periodSizeInFramesOut;
        pDevice->capture.internalPeriods            = data.periodsOut;
        ma_strcpy_s(pDevice->capture.name, sizeof(pDevice->capture.name), data.deviceName);

        ma_IAudioClient_SetEventHandle((ma_IAudioClient*)pDevice->wasapi.pAudioClientCapture, (HANDLE)pDevice->wasapi.hEventCapture);

        pDevice->wasapi.periodSizeInFramesCapture = data.periodSizeInFramesOut;
        ma_IAudioClient_GetBufferSize((ma_IAudioClient*)pDevice->wasapi.pAudioClientCapture, &pDevice->wasapi.actualBufferSizeInFramesCapture);

        /* We must always have a valid ID. */
        ma_strcpy_s_WCHAR(pDevice->capture.id.wasapi, sizeof(pDevice->capture.id.wasapi), data.id.wasapi);
    }

    if (deviceType == ma_device_type_playback) {
        pDevice->wasapi.pAudioClientPlayback         = data.pAudioClient;
        pDevice->wasapi.pRenderClient                = data.pRenderClient;

        pDevice->playback.internalFormat             = data.formatOut;
        pDevice->playback.internalChannels           = data.channelsOut;
        pDevice->playback.internalSampleRate         = data.sampleRateOut;
        MA_COPY_MEMORY(pDevice->playback.internalChannelMap, data.channelMapOut, sizeof(data.channelMapOut));
        pDevice->playback.internalPeriodSizeInFrames = data.periodSizeInFramesOut;
        pDevice->playback.internalPeriods            = data.periodsOut;
        ma_strcpy_s(pDevice->playback.name, sizeof(pDevice->playback.name), data.deviceName);

        ma_IAudioClient_SetEventHandle((ma_IAudioClient*)pDevice->wasapi.pAudioClientPlayback, (HANDLE)pDevice->wasapi.hEventPlayback);

        pDevice->wasapi.periodSizeInFramesPlayback = data.periodSizeInFramesOut;
        ma_IAudioClient_GetBufferSize((ma_IAudioClient*)pDevice->wasapi.pAudioClientPlayback, &pDevice->wasapi.actualBufferSizeInFramesPlayback);

        /* We must always have a valid ID because rerouting will look at it. */
        ma_strcpy_s_WCHAR(pDevice->playback.id.wasapi, sizeof(pDevice->playback.id.wasapi), data.id.wasapi);
    }

    return MA_SUCCESS;
}

static ma_result ma_device_init__wasapi(ma_device* pDevice, const ma_device_config* pConfig, ma_device_descriptor* pDescriptorPlayback, ma_device_descriptor* pDescriptorCapture)
{
    ma_result result = MA_SUCCESS;

#if defined(MA_WIN32_DESKTOP) || defined(MA_WIN32_GDK)
    HRESULT hr;
    ma_IMMDeviceEnumerator* pDeviceEnumerator;
#endif

    MA_ASSERT(pDevice != NULL);

    MA_ZERO_OBJECT(&pDevice->wasapi);
    pDevice->wasapi.usage                  = pConfig->wasapi.usage;
    pDevice->wasapi.noAutoConvertSRC       = pConfig->wasapi.noAutoConvertSRC;
    pDevice->wasapi.noDefaultQualitySRC    = pConfig->wasapi.noDefaultQualitySRC;
    pDevice->wasapi.noHardwareOffloading   = pConfig->wasapi.noHardwareOffloading;
    pDevice->wasapi.loopbackProcessID      = pConfig->wasapi.loopbackProcessID;
    pDevice->wasapi.loopbackProcessExclude = pConfig->wasapi.loopbackProcessExclude;

    /* Exclusive mode is not allowed with loopback. */
    if (pConfig->deviceType == ma_device_type_loopback && pConfig->playback.shareMode == ma_share_mode_exclusive) {
        return MA_INVALID_DEVICE_CONFIG;
    }

    if (pConfig->deviceType == ma_device_type_capture || pConfig->deviceType == ma_device_type_duplex || pConfig->deviceType == ma_device_type_loopback) {
        ma_device_init_internal_data__wasapi data;
        data.formatIn                   = pDescriptorCapture->format;
        data.channelsIn                 = pDescriptorCapture->channels;
        data.sampleRateIn               = pDescriptorCapture->sampleRate;
        MA_COPY_MEMORY(data.channelMapIn, pDescriptorCapture->channelMap, sizeof(pDescriptorCapture->channelMap));
        data.periodSizeInFramesIn       = pDescriptorCapture->periodSizeInFrames;
        data.periodSizeInMillisecondsIn = pDescriptorCapture->periodSizeInMilliseconds;
        data.periodsIn                  = pDescriptorCapture->periodCount;
        data.shareMode                  = pDescriptorCapture->shareMode;
        data.performanceProfile         = pConfig->performanceProfile;
        data.noAutoConvertSRC           = pConfig->wasapi.noAutoConvertSRC;
        data.noDefaultQualitySRC        = pConfig->wasapi.noDefaultQualitySRC;
        data.noHardwareOffloading       = pConfig->wasapi.noHardwareOffloading;
        data.loopbackProcessID          = pConfig->wasapi.loopbackProcessID;
        data.loopbackProcessExclude     = pConfig->wasapi.loopbackProcessExclude;

        result = ma_device_init_internal__wasapi(pDevice->pContext, (pConfig->deviceType == ma_device_type_loopback) ? ma_device_type_loopback : ma_device_type_capture, pDescriptorCapture->pDeviceID, &data);
        if (result != MA_SUCCESS) {
            return result;
        }

        pDevice->wasapi.pAudioClientCapture              = data.pAudioClient;
        pDevice->wasapi.pCaptureClient                   = data.pCaptureClient;
        pDevice->wasapi.originalPeriodSizeInMilliseconds = pDescriptorCapture->periodSizeInMilliseconds;
        pDevice->wasapi.originalPeriodSizeInFrames       = pDescriptorCapture->periodSizeInFrames;
        pDevice->wasapi.originalPeriods                  = pDescriptorCapture->periodCount;
        pDevice->wasapi.originalPerformanceProfile       = pConfig->performanceProfile;

        /*
        The event for capture needs to be manual reset for the same reason as playback. We keep the initial state set to unsignaled,
        however, because we want to block until we actually have something for the first call to ma_device_read().
        */
        pDevice->wasapi.hEventCapture = (ma_handle)CreateEventA(NULL, FALSE, FALSE, NULL);  /* Auto reset, unsignaled by default. */
        if (pDevice->wasapi.hEventCapture == NULL) {
            result = ma_result_from_GetLastError(GetLastError());

            if (pDevice->wasapi.pCaptureClient != NULL) {
                ma_IAudioCaptureClient_Release((ma_IAudioCaptureClient*)pDevice->wasapi.pCaptureClient);
                pDevice->wasapi.pCaptureClient = NULL;
            }
            if (pDevice->wasapi.pAudioClientCapture != NULL) {
                ma_IAudioClient_Release((ma_IAudioClient*)pDevice->wasapi.pAudioClientCapture);
                pDevice->wasapi.pAudioClientCapture = NULL;
            }

            ma_log_post(ma_device_get_log(pDevice), MA_LOG_LEVEL_ERROR, "[WASAPI] Failed to create event for capture.");
            return result;
        }
        ma_IAudioClient_SetEventHandle((ma_IAudioClient*)pDevice->wasapi.pAudioClientCapture, (HANDLE)pDevice->wasapi.hEventCapture);

        pDevice->wasapi.periodSizeInFramesCapture = data.periodSizeInFramesOut;
        ma_IAudioClient_GetBufferSize((ma_IAudioClient*)pDevice->wasapi.pAudioClientCapture, &pDevice->wasapi.actualBufferSizeInFramesCapture);

        /* We must always have a valid ID. */
        ma_strcpy_s_WCHAR(pDevice->capture.id.wasapi, sizeof(pDevice->capture.id.wasapi), data.id.wasapi);

        /* The descriptor needs to be updated with actual values. */
        pDescriptorCapture->format             = data.formatOut;
        pDescriptorCapture->channels           = data.channelsOut;
        pDescriptorCapture->sampleRate         = data.sampleRateOut;
        MA_COPY_MEMORY(pDescriptorCapture->channelMap, data.channelMapOut, sizeof(data.channelMapOut));
        pDescriptorCapture->periodSizeInFrames = data.periodSizeInFramesOut;
        pDescriptorCapture->periodCount        = data.periodsOut;
    }

    if (pConfig->deviceType == ma_device_type_playback || pConfig->deviceType == ma_device_type_duplex) {
        ma_device_init_internal_data__wasapi data;
        data.formatIn                   = pDescriptorPlayback->format;
        data.channelsIn                 = pDescriptorPlayback->channels;
        data.sampleRateIn               = pDescriptorPlayback->sampleRate;
        MA_COPY_MEMORY(data.channelMapIn, pDescriptorPlayback->channelMap, sizeof(pDescriptorPlayback->channelMap));
        data.periodSizeInFramesIn       = pDescriptorPlayback->periodSizeInFrames;
        data.periodSizeInMillisecondsIn = pDescriptorPlayback->periodSizeInMilliseconds;
        data.periodsIn                  = pDescriptorPlayback->periodCount;
        data.shareMode                  = pDescriptorPlayback->shareMode;
        data.performanceProfile         = pConfig->performanceProfile;
        data.noAutoConvertSRC           = pConfig->wasapi.noAutoConvertSRC;
        data.noDefaultQualitySRC        = pConfig->wasapi.noDefaultQualitySRC;
        data.noHardwareOffloading       = pConfig->wasapi.noHardwareOffloading;
        data.loopbackProcessID          = pConfig->wasapi.loopbackProcessID;
        data.loopbackProcessExclude     = pConfig->wasapi.loopbackProcessExclude;

        result = ma_device_init_internal__wasapi(pDevice->pContext, ma_device_type_playback, pDescriptorPlayback->pDeviceID, &data);
        if (result != MA_SUCCESS) {
            if (pConfig->deviceType == ma_device_type_duplex) {
                if (pDevice->wasapi.pCaptureClient != NULL) {
                    ma_IAudioCaptureClient_Release((ma_IAudioCaptureClient*)pDevice->wasapi.pCaptureClient);
                    pDevice->wasapi.pCaptureClient = NULL;
                }
                if (pDevice->wasapi.pAudioClientCapture != NULL) {
                    ma_IAudioClient_Release((ma_IAudioClient*)pDevice->wasapi.pAudioClientCapture);
                    pDevice->wasapi.pAudioClientCapture = NULL;
                }

                CloseHandle((HANDLE)pDevice->wasapi.hEventCapture);
                pDevice->wasapi.hEventCapture = NULL;
            }
            return result;
        }

        pDevice->wasapi.pAudioClientPlayback             = data.pAudioClient;
        pDevice->wasapi.pRenderClient                    = data.pRenderClient;
        pDevice->wasapi.originalPeriodSizeInMilliseconds = pDescriptorPlayback->periodSizeInMilliseconds;
        pDevice->wasapi.originalPeriodSizeInFrames       = pDescriptorPlayback->periodSizeInFrames;
        pDevice->wasapi.originalPeriods                  = pDescriptorPlayback->periodCount;
        pDevice->wasapi.originalPerformanceProfile       = pConfig->performanceProfile;

        /*
        The event for playback is needs to be manual reset because we want to explicitly control the fact that it becomes signalled
        only after the whole available space has been filled, never before.

        The playback event also needs to be initially set to a signaled state so that the first call to ma_device_write() is able
        to get passed WaitForMultipleObjects().
        */
        pDevice->wasapi.hEventPlayback = (ma_handle)CreateEventA(NULL, FALSE, TRUE, NULL);  /* Auto reset, signaled by default. */
        if (pDevice->wasapi.hEventPlayback == NULL) {
            result = ma_result_from_GetLastError(GetLastError());

            if (pConfig->deviceType == ma_device_type_duplex) {
                if (pDevice->wasapi.pCaptureClient != NULL) {
                    ma_IAudioCaptureClient_Release((ma_IAudioCaptureClient*)pDevice->wasapi.pCaptureClient);
                    pDevice->wasapi.pCaptureClient = NULL;
                }
                if (pDevice->wasapi.pAudioClientCapture != NULL) {
                    ma_IAudioClient_Release((ma_IAudioClient*)pDevice->wasapi.pAudioClientCapture);
                    pDevice->wasapi.pAudioClientCapture = NULL;
                }

                CloseHandle((HANDLE)pDevice->wasapi.hEventCapture);
                pDevice->wasapi.hEventCapture = NULL;
            }

            if (pDevice->wasapi.pRenderClient != NULL) {
                ma_IAudioRenderClient_Release((ma_IAudioRenderClient*)pDevice->wasapi.pRenderClient);
                pDevice->wasapi.pRenderClient = NULL;
            }
            if (pDevice->wasapi.pAudioClientPlayback != NULL) {
                ma_IAudioClient_Release((ma_IAudioClient*)pDevice->wasapi.pAudioClientPlayback);
                pDevice->wasapi.pAudioClientPlayback = NULL;
            }

            ma_log_post(ma_device_get_log(pDevice), MA_LOG_LEVEL_ERROR, "[WASAPI] Failed to create event for playback.");
            return result;
        }
        ma_IAudioClient_SetEventHandle((ma_IAudioClient*)pDevice->wasapi.pAudioClientPlayback, (HANDLE)pDevice->wasapi.hEventPlayback);

        pDevice->wasapi.periodSizeInFramesPlayback = data.periodSizeInFramesOut;
        ma_IAudioClient_GetBufferSize((ma_IAudioClient*)pDevice->wasapi.pAudioClientPlayback, &pDevice->wasapi.actualBufferSizeInFramesPlayback);

        /* We must always have a valid ID because rerouting will look at it. */
        ma_strcpy_s_WCHAR(pDevice->playback.id.wasapi, sizeof(pDevice->playback.id.wasapi), data.id.wasapi);

        /* The descriptor needs to be updated with actual values. */
        pDescriptorPlayback->format             = data.formatOut;
        pDescriptorPlayback->channels           = data.channelsOut;
        pDescriptorPlayback->sampleRate         = data.sampleRateOut;
        MA_COPY_MEMORY(pDescriptorPlayback->channelMap, data.channelMapOut, sizeof(data.channelMapOut));
        pDescriptorPlayback->periodSizeInFrames = data.periodSizeInFramesOut;
        pDescriptorPlayback->periodCount        = data.periodsOut;
    }

    /*
    We need to register a notification client to detect when the device has been disabled, unplugged or re-routed (when the default device changes). When
    we are connecting to the default device we want to do automatic stream routing when the device is disabled or unplugged. Otherwise we want to just
    stop the device outright and let the application handle it.
    */
#if defined(MA_WIN32_DESKTOP) || defined(MA_WIN32_GDK)
    if (pConfig->wasapi.noAutoStreamRouting == MA_FALSE) {
        if ((pConfig->deviceType == ma_device_type_capture || pConfig->deviceType == ma_device_type_duplex || pConfig->deviceType == ma_device_type_loopback) && pConfig->capture.pDeviceID == NULL) {
            pDevice->wasapi.allowCaptureAutoStreamRouting = MA_TRUE;
        }
        if ((pConfig->deviceType == ma_device_type_playback || pConfig->deviceType == ma_device_type_duplex) && pConfig->playback.pDeviceID == NULL) {
            pDevice->wasapi.allowPlaybackAutoStreamRouting = MA_TRUE;
        }
    }

    ma_mutex_init(&pDevice->wasapi.rerouteLock);

    hr = ma_CoCreateInstance(pDevice->pContext, &MA_CLSID_MMDeviceEnumerator, NULL, CLSCTX_ALL, &MA_IID_IMMDeviceEnumerator, (void**)&pDeviceEnumerator);
    if (FAILED(hr)) {
        ma_device_uninit__wasapi(pDevice);
        ma_log_post(ma_device_get_log(pDevice), MA_LOG_LEVEL_ERROR, "[WASAPI] Failed to create device enumerator.");
        return ma_result_from_HRESULT(hr);
    }

    pDevice->wasapi.notificationClient.lpVtbl  = (void*)&g_maNotificationCientVtbl;
    pDevice->wasapi.notificationClient.counter = 1;
    pDevice->wasapi.notificationClient.pDevice = pDevice;

    hr = pDeviceEnumerator->lpVtbl->RegisterEndpointNotificationCallback(pDeviceEnumerator, &pDevice->wasapi.notificationClient);
    if (SUCCEEDED(hr)) {
        pDevice->wasapi.pDeviceEnumerator = (ma_ptr)pDeviceEnumerator;
    } else {
        /* Not the end of the world if we fail to register the notification callback. We just won't support automatic stream routing. */
        ma_IMMDeviceEnumerator_Release(pDeviceEnumerator);
    }
#endif

    ma_atomic_bool32_set(&pDevice->wasapi.isStartedCapture,  MA_FALSE);
    ma_atomic_bool32_set(&pDevice->wasapi.isStartedPlayback, MA_FALSE);

    return MA_SUCCESS;
}

static ma_result ma_device__get_available_frames__wasapi(ma_device* pDevice, ma_IAudioClient* pAudioClient, ma_uint32* pFrameCount)
{
    ma_uint32 paddingFramesCount;
    HRESULT hr;
    ma_share_mode shareMode;

    MA_ASSERT(pDevice != NULL);
    MA_ASSERT(pFrameCount != NULL);

    *pFrameCount = 0;

    if ((ma_ptr)pAudioClient != pDevice->wasapi.pAudioClientPlayback && (ma_ptr)pAudioClient != pDevice->wasapi.pAudioClientCapture) {
        return MA_INVALID_OPERATION;
    }

    /*
    I've had a report that GetCurrentPadding() is returning a frame count of 0 which is preventing
    higher level function calls from doing anything because it thinks nothing is available. I have
    taken a look at the documentation and it looks like this is unnecessary in exclusive mode.

    From Microsoft's documentation:

        For an exclusive-mode rendering or capture stream that was initialized with the
        AUDCLNT_STREAMFLAGS_EVENTCALLBACK flag, the client typically has no use for the padding
        value reported by GetCurrentPadding. Instead, the client accesses an entire buffer during
        each processing pass.

    Considering this, I'm going to skip GetCurrentPadding() for exclusive mode and just report the
    entire buffer. This depends on the caller making sure they wait on the event handler.
    */
    shareMode = ((ma_ptr)pAudioClient == pDevice->wasapi.pAudioClientPlayback) ? pDevice->playback.shareMode : pDevice->capture.shareMode;
    if (shareMode == ma_share_mode_shared) {
        /* Shared mode. */
        hr = ma_IAudioClient_GetCurrentPadding(pAudioClient, &paddingFramesCount);
        if (FAILED(hr)) {
            return ma_result_from_HRESULT(hr);
        }

        if ((ma_ptr)pAudioClient == pDevice->wasapi.pAudioClientPlayback) {
            *pFrameCount = pDevice->wasapi.actualBufferSizeInFramesPlayback - paddingFramesCount;
        } else {
            *pFrameCount = paddingFramesCount;
        }
    } else {
        /* Exclusive mode. */
        if ((ma_ptr)pAudioClient == pDevice->wasapi.pAudioClientPlayback) {
            *pFrameCount = pDevice->wasapi.actualBufferSizeInFramesPlayback;
        } else {
            *pFrameCount = pDevice->wasapi.actualBufferSizeInFramesCapture;
        }
    }

    return MA_SUCCESS;
}


static ma_result ma_device_reroute__wasapi(ma_device* pDevice, ma_device_type deviceType)
{
    ma_result result;

    if (deviceType == ma_device_type_duplex) {
        return MA_INVALID_ARGS;
    }

    ma_log_postf(ma_device_get_log(pDevice), MA_LOG_LEVEL_DEBUG, "=== CHANGING DEVICE ===\n");

    result = ma_device_reinit__wasapi(pDevice, deviceType);
    if (result != MA_SUCCESS) {
        ma_log_postf(ma_device_get_log(pDevice), MA_LOG_LEVEL_WARNING, "[WASAPI] Reinitializing device after route change failed.\n");
        return result;
    }

    ma_device__post_init_setup(pDevice, deviceType);
    ma_device__on_notification_rerouted(pDevice);

    ma_log_postf(ma_device_get_log(pDevice), MA_LOG_LEVEL_DEBUG, "=== DEVICE CHANGED ===\n");

    return MA_SUCCESS;
}

static ma_result ma_device_start__wasapi_nolock(ma_device* pDevice)
{
    HRESULT hr;

    if (pDevice->pContext->wasapi.hAvrt) {
        const char* pTaskName = ma_to_usage_string__wasapi(pDevice->wasapi.usage);
        if (pTaskName) {
            DWORD idx = 0;
            pDevice->wasapi.hAvrtHandle = (ma_handle)((MA_PFN_AvSetMmThreadCharacteristicsA)pDevice->pContext->wasapi.AvSetMmThreadCharacteristicsA)(pTaskName, &idx);
        }
    }

    if (pDevice->type == ma_device_type_capture || pDevice->type == ma_device_type_duplex || pDevice->type == ma_device_type_loopback) {
        hr = ma_IAudioClient_Start((ma_IAudioClient*)pDevice->wasapi.pAudioClientCapture);
        if (FAILED(hr)) {
            ma_log_postf(ma_device_get_log(pDevice), MA_LOG_LEVEL_ERROR, "[WASAPI] Failed to start internal capture device. HRESULT = %d.", (int)hr);
            return ma_result_from_HRESULT(hr);
        }

        ma_atomic_bool32_set(&pDevice->wasapi.isStartedCapture, MA_TRUE);
    }

    if (pDevice->type == ma_device_type_playback || pDevice->type == ma_device_type_duplex) {
        hr = ma_IAudioClient_Start((ma_IAudioClient*)pDevice->wasapi.pAudioClientPlayback);
        if (FAILED(hr)) {
            ma_log_postf(ma_device_get_log(pDevice), MA_LOG_LEVEL_ERROR, "[WASAPI] Failed to start internal playback device. HRESULT = %d.", (int)hr);
            return ma_result_from_HRESULT(hr);
        }

        ma_atomic_bool32_set(&pDevice->wasapi.isStartedPlayback, MA_TRUE);
    }

    return MA_SUCCESS;
}

static ma_result ma_device_start__wasapi(ma_device* pDevice)
{
    ma_result result;

    MA_ASSERT(pDevice != NULL);

    /* Wait for any rerouting to finish before attempting to start the device. */
    ma_mutex_lock(&pDevice->wasapi.rerouteLock);
    {
        result = ma_device_start__wasapi_nolock(pDevice);
    }
    ma_mutex_unlock(&pDevice->wasapi.rerouteLock);

    return result;
}

static ma_result ma_device_stop__wasapi_nolock(ma_device* pDevice)
{
    ma_result result;
    HRESULT hr;

    MA_ASSERT(pDevice != NULL);

    if (pDevice->wasapi.hAvrtHandle) {
        ((MA_PFN_AvRevertMmThreadCharacteristics)pDevice->pContext->wasapi.AvRevertMmThreadcharacteristics)((HANDLE)pDevice->wasapi.hAvrtHandle);
        pDevice->wasapi.hAvrtHandle = NULL;
    }

    if (pDevice->type == ma_device_type_capture || pDevice->type == ma_device_type_duplex || pDevice->type == ma_device_type_loopback) {
        hr = ma_IAudioClient_Stop((ma_IAudioClient*)pDevice->wasapi.pAudioClientCapture);
        if (FAILED(hr)) {
            ma_log_post(ma_device_get_log(pDevice), MA_LOG_LEVEL_ERROR, "[WASAPI] Failed to stop internal capture device.");
            return ma_result_from_HRESULT(hr);
        }

        /* The audio client needs to be reset otherwise restarting will fail. */
        hr = ma_IAudioClient_Reset((ma_IAudioClient*)pDevice->wasapi.pAudioClientCapture);
        if (FAILED(hr)) {
            ma_log_post(ma_device_get_log(pDevice), MA_LOG_LEVEL_ERROR, "[WASAPI] Failed to reset internal capture device.");
            return ma_result_from_HRESULT(hr);
        }

        /* If we have a mapped buffer we need to release it. */
        if (pDevice->wasapi.pMappedBufferCapture != NULL) {
            ma_IAudioCaptureClient_ReleaseBuffer((ma_IAudioCaptureClient*)pDevice->wasapi.pCaptureClient, pDevice->wasapi.mappedBufferCaptureCap);
            pDevice->wasapi.pMappedBufferCapture = NULL;
            pDevice->wasapi.mappedBufferCaptureCap = 0;
            pDevice->wasapi.mappedBufferCaptureLen = 0;
        }

        ma_atomic_bool32_set(&pDevice->wasapi.isStartedCapture, MA_FALSE);
    }

    if (pDevice->type == ma_device_type_playback || pDevice->type == ma_device_type_duplex) {
        /*
        The buffer needs to be drained before stopping the device. Not doing this will result in the last few frames not getting output to
        the speakers. This is a problem for very short sounds because it'll result in a significant portion of it not getting played.
        */
        if (ma_atomic_bool32_get(&pDevice->wasapi.isStartedPlayback)) {
            /* We need to make sure we put a timeout here or else we'll risk getting stuck in a deadlock in some cases. */
            DWORD waitTime = pDevice->wasapi.actualBufferSizeInFramesPlayback / pDevice->playback.internalSampleRate;

            if (pDevice->playback.shareMode == ma_share_mode_exclusive) {
                WaitForSingleObject((HANDLE)pDevice->wasapi.hEventPlayback, waitTime);
            }
            else {
                ma_uint32 prevFramesAvaialablePlayback = (ma_uint32)-1;
                ma_uint32 framesAvailablePlayback;
                for (;;) {
                    result = ma_device__get_available_frames__wasapi(pDevice, (ma_IAudioClient*)pDevice->wasapi.pAudioClientPlayback, &framesAvailablePlayback);
                    if (result != MA_SUCCESS) {
                        break;
                    }

                    if (framesAvailablePlayback >= pDevice->wasapi.actualBufferSizeInFramesPlayback) {
                        break;
                    }

                    /*
                    Just a safety check to avoid an infinite loop. If this iteration results in a situation where the number of available frames
                    has not changed, get out of the loop. I don't think this should ever happen, but I think it's nice to have just in case.
                    */
                    if (framesAvailablePlayback == prevFramesAvaialablePlayback) {
                        break;
                    }
                    prevFramesAvaialablePlayback = framesAvailablePlayback;

                    WaitForSingleObject((HANDLE)pDevice->wasapi.hEventPlayback, waitTime * 1000);
                    ResetEvent((HANDLE)pDevice->wasapi.hEventPlayback); /* Manual reset. */
                }
            }
        }

        hr = ma_IAudioClient_Stop((ma_IAudioClient*)pDevice->wasapi.pAudioClientPlayback);
        if (FAILED(hr)) {
            ma_log_post(ma_device_get_log(pDevice), MA_LOG_LEVEL_ERROR, "[WASAPI] Failed to stop internal playback device.");
            return ma_result_from_HRESULT(hr);
        }

        /* The audio client needs to be reset otherwise restarting will fail. */
        hr = ma_IAudioClient_Reset((ma_IAudioClient*)pDevice->wasapi.pAudioClientPlayback);
        if (FAILED(hr)) {
            ma_log_post(ma_device_get_log(pDevice), MA_LOG_LEVEL_ERROR, "[WASAPI] Failed to reset internal playback device.");
            return ma_result_from_HRESULT(hr);
        }

        if (pDevice->wasapi.pMappedBufferPlayback != NULL) {
            ma_IAudioRenderClient_ReleaseBuffer((ma_IAudioRenderClient*)pDevice->wasapi.pRenderClient, pDevice->wasapi.mappedBufferPlaybackCap, 0);
            pDevice->wasapi.pMappedBufferPlayback = NULL;
            pDevice->wasapi.mappedBufferPlaybackCap = 0;
            pDevice->wasapi.mappedBufferPlaybackLen = 0;
        }

        ma_atomic_bool32_set(&pDevice->wasapi.isStartedPlayback, MA_FALSE);
    }

    return MA_SUCCESS;
}

static ma_result ma_device_stop__wasapi(ma_device* pDevice)
{
    ma_result result;

    MA_ASSERT(pDevice != NULL);

    /* Wait for any rerouting to finish before attempting to stop the device. */
    ma_mutex_lock(&pDevice->wasapi.rerouteLock);
    {
        result = ma_device_stop__wasapi_nolock(pDevice);
    }
    ma_mutex_unlock(&pDevice->wasapi.rerouteLock);

    return result;
}


#ifndef MA_WASAPI_WAIT_TIMEOUT_MILLISECONDS
#define MA_WASAPI_WAIT_TIMEOUT_MILLISECONDS 5000
#endif

static ma_result ma_device_read__wasapi(ma_device* pDevice, void* pFrames, ma_uint32 frameCount, ma_uint32* pFramesRead)
{
    ma_result result = MA_SUCCESS;
    ma_uint32 totalFramesProcessed = 0;

    /*
    When reading, we need to get a buffer and process all of it before releasing it. Because the
    frame count (frameCount) can be different to the size of the buffer, we'll need to cache the
    pointer to the buffer.
    */

    /* Keep running until we've processed the requested number of frames. */
    while (ma_device_get_state(pDevice) == ma_device_state_started && totalFramesProcessed < frameCount) {
        ma_uint32 framesRemaining = frameCount - totalFramesProcessed;

        /* If we have a mapped data buffer, consume that first. */
        if (pDevice->wasapi.pMappedBufferCapture != NULL) {
            /* We have a cached data pointer so consume that before grabbing another one from WASAPI. */
            ma_uint32 framesToProcessNow = framesRemaining;
            if (framesToProcessNow > pDevice->wasapi.mappedBufferCaptureLen) {
                framesToProcessNow = pDevice->wasapi.mappedBufferCaptureLen;
            }

            /* Now just copy the data over to the output buffer. */
            ma_copy_pcm_frames(
                ma_offset_pcm_frames_ptr(pFrames, totalFramesProcessed, pDevice->capture.internalFormat, pDevice->capture.internalChannels),
                ma_offset_pcm_frames_const_ptr(pDevice->wasapi.pMappedBufferCapture, pDevice->wasapi.mappedBufferCaptureCap - pDevice->wasapi.mappedBufferCaptureLen, pDevice->capture.internalFormat, pDevice->capture.internalChannels),
                framesToProcessNow,
                pDevice->capture.internalFormat, pDevice->capture.internalChannels
            );

            totalFramesProcessed                   += framesToProcessNow;
            pDevice->wasapi.mappedBufferCaptureLen -= framesToProcessNow;

            /* If the data buffer has been fully consumed we need to release it. */
            if (pDevice->wasapi.mappedBufferCaptureLen == 0) {
                ma_IAudioCaptureClient_ReleaseBuffer((ma_IAudioCaptureClient*)pDevice->wasapi.pCaptureClient, pDevice->wasapi.mappedBufferCaptureCap);
                pDevice->wasapi.pMappedBufferCapture   = NULL;
                pDevice->wasapi.mappedBufferCaptureCap = 0;
            }
        } else {
            /* We don't have any cached data pointer, so grab another one. */
            HRESULT hr;
            DWORD flags = 0;

            /* First just ask WASAPI for a data buffer. If it's not available, we'll wait for more. */
            hr = ma_IAudioCaptureClient_GetBuffer((ma_IAudioCaptureClient*)pDevice->wasapi.pCaptureClient, (BYTE**)&pDevice->wasapi.pMappedBufferCapture, &pDevice->wasapi.mappedBufferCaptureCap, &flags, NULL, NULL);
            if (hr == S_OK) {
                /* We got a data buffer. Continue to the next loop iteration which will then read from the mapped pointer. */
                pDevice->wasapi.mappedBufferCaptureLen = pDevice->wasapi.mappedBufferCaptureCap;

                /*
                There have been reports that indicate that at times the AUDCLNT_BUFFERFLAGS_DATA_DISCONTINUITY is reported for every
                call to IAudioCaptureClient_GetBuffer() above which results in spamming of the debug messages below. To partially
                work around this, I'm only outputting these messages when MA_DEBUG_OUTPUT is explicitly defined. The better solution
                would be to figure out why the flag is always getting reported.
                */
                #if defined(MA_DEBUG_OUTPUT)
                {
                    if (flags != 0) {
                        ma_log_postf(ma_device_get_log(pDevice), MA_LOG_LEVEL_DEBUG, "[WASAPI] Capture Flags: %ld\n", flags);

                        if ((flags & MA_AUDCLNT_BUFFERFLAGS_DATA_DISCONTINUITY) != 0) {
                            ma_log_postf(ma_device_get_log(pDevice), MA_LOG_LEVEL_DEBUG, "[WASAPI] Data discontinuity (possible overrun). Attempting recovery. mappedBufferCaptureCap=%d\n", pDevice->wasapi.mappedBufferCaptureCap);
                        }
                    }
                }
                #endif

                /* Overrun detection. */
                if ((flags & MA_AUDCLNT_BUFFERFLAGS_DATA_DISCONTINUITY) != 0) {
                    /* Glitched. Probably due to an overrun. */

                    /*
                    If we got an overrun it probably means we're straddling the end of the buffer. In normal capture
                    mode this is the fault of the client application because they're responsible for ensuring data is
                    processed fast enough. In duplex mode, however, the processing of audio is tied to the playback
                    device, so this can possibly be the result of a timing de-sync.

                    In capture mode we're not going to do any kind of recovery because the real fix is for the client
                    application to process faster. In duplex mode, we'll treat this as a desync and reset the buffers
                    to prevent a never-ending sequence of glitches due to straddling the end of the buffer.
                    */
                    if (pDevice->type == ma_device_type_duplex) {
                        /*
                        Experiment:

                        If we empty out the *entire* buffer we may end up putting ourselves into an underrun position
                        which isn't really any better than the overrun we're probably in right now. Instead we'll just
                        empty out about half.
                        */
                        ma_uint32 i;
                        ma_uint32 periodCount = (pDevice->wasapi.actualBufferSizeInFramesCapture / pDevice->wasapi.periodSizeInFramesCapture);
                        ma_uint32 iterationCount = periodCount / 2;
                        if ((periodCount % 2) > 0) {
                            iterationCount += 1;
                        }

                        for (i = 0; i < iterationCount; i += 1) {
                            hr = ma_IAudioCaptureClient_ReleaseBuffer((ma_IAudioCaptureClient*)pDevice->wasapi.pCaptureClient, pDevice->wasapi.mappedBufferCaptureCap);
                            if (FAILED(hr)) {
                                ma_log_postf(ma_device_get_log(pDevice), MA_LOG_LEVEL_DEBUG, "[WASAPI] Data discontinuity recovery: IAudioCaptureClient_ReleaseBuffer() failed with %ld.\n", hr);
                                break;
                            }

                            flags = 0;
                            hr = ma_IAudioCaptureClient_GetBuffer((ma_IAudioCaptureClient*)pDevice->wasapi.pCaptureClient, (BYTE**)&pDevice->wasapi.pMappedBufferCapture, &pDevice->wasapi.mappedBufferCaptureCap, &flags, NULL, NULL);
                            if (hr == MA_AUDCLNT_S_BUFFER_EMPTY || FAILED(hr)) {
                                /*
                                The buffer has been completely emptied or an error occurred. In this case we'll need
                                to reset the state of the mapped buffer which will trigger the next iteration to get
                                a fresh buffer from WASAPI.
                                */
                                pDevice->wasapi.pMappedBufferCapture   = NULL;
                                pDevice->wasapi.mappedBufferCaptureCap = 0;
                                pDevice->wasapi.mappedBufferCaptureLen = 0;

                                if (hr == MA_AUDCLNT_S_BUFFER_EMPTY) {
                                    if ((flags & MA_AUDCLNT_BUFFERFLAGS_DATA_DISCONTINUITY) != 0) {
                                        ma_log_postf(ma_device_get_log(pDevice), MA_LOG_LEVEL_DEBUG, "[WASAPI] Data discontinuity recovery: Buffer emptied, and data discontinuity still reported.\n");
                                    } else {
                                        ma_log_postf(ma_device_get_log(pDevice), MA_LOG_LEVEL_DEBUG, "[WASAPI] Data discontinuity recovery: Buffer emptied.\n");
                                    }
                                }

                                if (FAILED(hr)) {
                                    ma_log_postf(ma_device_get_log(pDevice), MA_LOG_LEVEL_DEBUG, "[WASAPI] Data discontinuity recovery: IAudioCaptureClient_GetBuffer() failed with %ld.\n", hr);
                                }

                                break;
                            }
                        }

                        /* If at this point we have a valid buffer mapped, make sure the buffer length is set appropriately. */
                        if (pDevice->wasapi.pMappedBufferCapture != NULL) {
                            pDevice->wasapi.mappedBufferCaptureLen = pDevice->wasapi.mappedBufferCaptureCap;
                        }
                    }
                }

                continue;
            } else {
                if (hr == MA_AUDCLNT_S_BUFFER_EMPTY || hr == MA_AUDCLNT_E_BUFFER_ERROR) {
                    /*
                    No data is available. We need to wait for more. There's two situations to consider
                    here. The first is normal capture mode. If this times out it probably means the
                    microphone isn't delivering data for whatever reason. In this case we'll just
                    abort the read and return whatever we were able to get. The other situations is
                    loopback mode, in which case a timeout probably just means the nothing is playing
                    through the speakers.
                    */

                    /* Experiment: Use a shorter timeout for loopback mode. */
                    DWORD timeoutInMilliseconds = MA_WASAPI_WAIT_TIMEOUT_MILLISECONDS;
                    if (pDevice->type == ma_device_type_loopback) {
                        timeoutInMilliseconds = 10;
                    }

                    if (WaitForSingleObject((HANDLE)pDevice->wasapi.hEventCapture, timeoutInMilliseconds) != WAIT_OBJECT_0) {
                        if (pDevice->type == ma_device_type_loopback) {
                            continue;   /* Keep waiting in loopback mode. */
                        } else {
                            result = MA_ERROR;
                            break;      /* Wait failed. */
                        }
                    }

                    /* At this point we should be able to loop back to the start of the loop and try retrieving a data buffer again. */
                } else {
                    /* An error occurred and we need to abort. */
                    ma_log_postf(ma_device_get_log(pDevice), MA_LOG_LEVEL_ERROR, "[WASAPI] Failed to retrieve internal buffer from capture device in preparation for reading from the device. HRESULT = %d. Stopping device.\n", (int)hr);
                    result = ma_result_from_HRESULT(hr);
                    break;
                }
            }
        }
    }

    /*
    If we were unable to process the entire requested frame count, but we still have a mapped buffer,
    there's a good chance either an error occurred or the device was stopped mid-read. In this case
    we'll need to make sure the buffer is released.
    */
    if (totalFramesProcessed < frameCount && pDevice->wasapi.pMappedBufferCapture != NULL) {
        ma_IAudioCaptureClient_ReleaseBuffer((ma_IAudioCaptureClient*)pDevice->wasapi.pCaptureClient, pDevice->wasapi.mappedBufferCaptureCap);
        pDevice->wasapi.pMappedBufferCapture   = NULL;
        pDevice->wasapi.mappedBufferCaptureCap = 0;
        pDevice->wasapi.mappedBufferCaptureLen = 0;
    }

    if (pFramesRead != NULL) {
        *pFramesRead = totalFramesProcessed;
    }

    return result;
}

static ma_result ma_device_write__wasapi(ma_device* pDevice, const void* pFrames, ma_uint32 frameCount, ma_uint32* pFramesWritten)
{
    ma_result result = MA_SUCCESS;
    ma_uint32 totalFramesProcessed = 0;

    /* Keep writing to the device until it's stopped or we've consumed all of our input. */
    while (ma_device_get_state(pDevice) == ma_device_state_started && totalFramesProcessed < frameCount) {
        ma_uint32 framesRemaining = frameCount - totalFramesProcessed;

        /*
        We're going to do this in a similar way to capture. We'll first check if the cached data pointer
        is valid, and if so, read from that. Otherwise We will call IAudioRenderClient_GetBuffer() with
        a requested buffer size equal to our actual period size. If it returns AUDCLNT_E_BUFFER_TOO_LARGE
        it means we need to wait for some data to become available.
        */
        if (pDevice->wasapi.pMappedBufferPlayback != NULL) {
            /* We still have some space available in the mapped data buffer. Write to it. */
            ma_uint32 framesToProcessNow = framesRemaining;
            if (framesToProcessNow > (pDevice->wasapi.mappedBufferPlaybackCap - pDevice->wasapi.mappedBufferPlaybackLen)) {
                framesToProcessNow = (pDevice->wasapi.mappedBufferPlaybackCap - pDevice->wasapi.mappedBufferPlaybackLen);
            }

            /* Now just copy the data over to the output buffer. */
            ma_copy_pcm_frames(
                ma_offset_pcm_frames_ptr(pDevice->wasapi.pMappedBufferPlayback, pDevice->wasapi.mappedBufferPlaybackLen, pDevice->playback.internalFormat, pDevice->playback.internalChannels),
                ma_offset_pcm_frames_const_ptr(pFrames, totalFramesProcessed, pDevice->playback.internalFormat, pDevice->playback.internalChannels),
                framesToProcessNow,
                pDevice->playback.internalFormat, pDevice->playback.internalChannels
            );

            totalFramesProcessed                    += framesToProcessNow;
            pDevice->wasapi.mappedBufferPlaybackLen += framesToProcessNow;

            /* If the data buffer has been fully consumed we need to release it. */
            if (pDevice->wasapi.mappedBufferPlaybackLen == pDevice->wasapi.mappedBufferPlaybackCap) {
                ma_IAudioRenderClient_ReleaseBuffer((ma_IAudioRenderClient*)pDevice->wasapi.pRenderClient, pDevice->wasapi.mappedBufferPlaybackCap, 0);
                pDevice->wasapi.pMappedBufferPlayback   = NULL;
                pDevice->wasapi.mappedBufferPlaybackCap = 0;
                pDevice->wasapi.mappedBufferPlaybackLen = 0;

                /*
                In exclusive mode we need to wait here. Exclusive mode is weird because GetBuffer() never
                seems to return AUDCLNT_E_BUFFER_TOO_LARGE, which is what we normally use to determine
                whether or not we need to wait for more data.
                */
                if (pDevice->playback.shareMode == ma_share_mode_exclusive) {
                    if (WaitForSingleObject((HANDLE)pDevice->wasapi.hEventPlayback, MA_WASAPI_WAIT_TIMEOUT_MILLISECONDS) != WAIT_OBJECT_0) {
                        result = MA_ERROR;
                        break;   /* Wait failed. Probably timed out. */
                    }
                }
            }
        } else {
            /* We don't have a mapped data buffer so we'll need to get one. */
            HRESULT hr;
            ma_uint32 bufferSizeInFrames;

            /* Special rules for exclusive mode. */
            if (pDevice->playback.shareMode == ma_share_mode_exclusive) {
                bufferSizeInFrames = pDevice->wasapi.actualBufferSizeInFramesPlayback;
            } else {
                bufferSizeInFrames = pDevice->wasapi.periodSizeInFramesPlayback;
            }

            hr = ma_IAudioRenderClient_GetBuffer((ma_IAudioRenderClient*)pDevice->wasapi.pRenderClient, bufferSizeInFrames, (BYTE**)&pDevice->wasapi.pMappedBufferPlayback);
            if (hr == S_OK) {
                /* We have data available. */
                pDevice->wasapi.mappedBufferPlaybackCap = bufferSizeInFrames;
                pDevice->wasapi.mappedBufferPlaybackLen = 0;
            } else {
                if (hr == MA_AUDCLNT_E_BUFFER_TOO_LARGE || hr == MA_AUDCLNT_E_BUFFER_ERROR) {
                    /* Not enough data available. We need to wait for more. */
                    if (WaitForSingleObject((HANDLE)pDevice->wasapi.hEventPlayback, MA_WASAPI_WAIT_TIMEOUT_MILLISECONDS) != WAIT_OBJECT_0) {
                        result = MA_ERROR;
                        break;   /* Wait failed. Probably timed out. */
                    }
                } else {
                    /* Some error occurred. We'll need to abort. */
                    ma_log_postf(ma_device_get_log(pDevice), MA_LOG_LEVEL_ERROR, "[WASAPI] Failed to retrieve internal buffer from playback device in preparation for writing to the device. HRESULT = %d. Stopping device.\n", (int)hr);
                    result = ma_result_from_HRESULT(hr);
                    break;
                }
            }
        }
    }

    if (pFramesWritten != NULL) {
        *pFramesWritten = totalFramesProcessed;
    }

    return result;
}

static ma_result ma_device_data_loop_wakeup__wasapi(ma_device* pDevice)
{
    MA_ASSERT(pDevice != NULL);

    if (pDevice->type == ma_device_type_capture || pDevice->type == ma_device_type_duplex || pDevice->type == ma_device_type_loopback) {
        SetEvent((HANDLE)pDevice->wasapi.hEventCapture);
    }

    if (pDevice->type == ma_device_type_playback || pDevice->type == ma_device_type_duplex) {
        SetEvent((HANDLE)pDevice->wasapi.hEventPlayback);
    }

    return MA_SUCCESS;
}


static ma_result ma_context_uninit__wasapi(ma_context* pContext)
{
    ma_context_command__wasapi cmd = ma_context_init_command__wasapi(MA_CONTEXT_COMMAND_QUIT__WASAPI);

    MA_ASSERT(pContext != NULL);
    MA_ASSERT(pContext->backend == ma_backend_wasapi);

    ma_context_post_command__wasapi(pContext, &cmd);
    ma_thread_wait(&pContext->wasapi.commandThread);

    if (pContext->wasapi.hAvrt) {
        ma_dlclose(ma_context_get_log(pContext), pContext->wasapi.hAvrt);
        pContext->wasapi.hAvrt = NULL;
    }

    #if defined(MA_WIN32_UWP)
    {
        if (pContext->wasapi.hMMDevapi) {
            ma_dlclose(ma_context_get_log(pContext), pContext->wasapi.hMMDevapi);
            pContext->wasapi.hMMDevapi = NULL;
        }
    }
    #endif

    /* Only after the thread has been terminated can we uninitialize the sync objects for the command thread. */
    ma_semaphore_uninit(&pContext->wasapi.commandSem);
    ma_mutex_uninit(&pContext->wasapi.commandLock);

    return MA_SUCCESS;
}

static ma_result ma_context_init__wasapi(ma_context* pContext, const ma_context_config* pConfig, ma_backend_callbacks* pCallbacks)
{
    ma_result result = MA_SUCCESS;

    MA_ASSERT(pContext != NULL);

    (void)pConfig;

#ifdef MA_WIN32_DESKTOP
    /*
    WASAPI is only supported in Vista SP1 and newer. The reason for SP1 and not the base version of Vista is that event-driven
    exclusive mode does not work until SP1.

    Unfortunately older compilers don't define these functions so we need to dynamically load them in order to avoid a link error.
    */
    {
        ma_OSVERSIONINFOEXW osvi;
        ma_handle kernel32DLL;
        ma_PFNVerifyVersionInfoW _VerifyVersionInfoW;
        ma_PFNVerSetConditionMask _VerSetConditionMask;

        kernel32DLL = ma_dlopen(ma_context_get_log(pContext), "kernel32.dll");
        if (kernel32DLL == NULL) {
            return MA_NO_BACKEND;
        }

        _VerifyVersionInfoW  = (ma_PFNVerifyVersionInfoW )ma_dlsym(ma_context_get_log(pContext), kernel32DLL, "VerifyVersionInfoW");
        _VerSetConditionMask = (ma_PFNVerSetConditionMask)ma_dlsym(ma_context_get_log(pContext), kernel32DLL, "VerSetConditionMask");
        if (_VerifyVersionInfoW == NULL || _VerSetConditionMask == NULL) {
            ma_dlclose(ma_context_get_log(pContext), kernel32DLL);
            return MA_NO_BACKEND;
        }

        MA_ZERO_OBJECT(&osvi);
        osvi.dwOSVersionInfoSize = sizeof(osvi);
        osvi.dwMajorVersion = ((MA_WIN32_WINNT_VISTA >> 8) & 0xFF);
        osvi.dwMinorVersion = ((MA_WIN32_WINNT_VISTA >> 0) & 0xFF);
        osvi.wServicePackMajor = 1;
        if (_VerifyVersionInfoW(&osvi, MA_VER_MAJORVERSION | MA_VER_MINORVERSION | MA_VER_SERVICEPACKMAJOR, _VerSetConditionMask(_VerSetConditionMask(_VerSetConditionMask(0, MA_VER_MAJORVERSION, MA_VER_GREATER_EQUAL), MA_VER_MINORVERSION, MA_VER_GREATER_EQUAL), MA_VER_SERVICEPACKMAJOR, MA_VER_GREATER_EQUAL))) {
            result = MA_SUCCESS;
        } else {
            result = MA_NO_BACKEND;
        }

        ma_dlclose(ma_context_get_log(pContext), kernel32DLL);
    }
#endif

    if (result != MA_SUCCESS) {
        return result;
    }

    MA_ZERO_OBJECT(&pContext->wasapi);


    #if defined(MA_WIN32_UWP)
    {
        /* Link to mmdevapi so we can get access to ActivateAudioInterfaceAsync(). */
        pContext->wasapi.hMMDevapi = ma_dlopen(ma_context_get_log(pContext), "mmdevapi.dll");
        if (pContext->wasapi.hMMDevapi) {
            pContext->wasapi.ActivateAudioInterfaceAsync = ma_dlsym(ma_context_get_log(pContext), pContext->wasapi.hMMDevapi, "ActivateAudioInterfaceAsync");
            if (pContext->wasapi.ActivateAudioInterfaceAsync == NULL) {
                ma_dlclose(ma_context_get_log(pContext), pContext->wasapi.hMMDevapi);
                return MA_NO_BACKEND;   /* ActivateAudioInterfaceAsync() could not be loaded. */
            }
        } else {
            return MA_NO_BACKEND;   /* Failed to load mmdevapi.dll which is required for ActivateAudioInterfaceAsync() */
        }
    }
    #endif

    /* Optionally use the Avrt API to specify the audio thread's latency sensitivity requirements */
    pContext->wasapi.hAvrt = ma_dlopen(ma_context_get_log(pContext), "avrt.dll");
    if (pContext->wasapi.hAvrt) {
        pContext->wasapi.AvSetMmThreadCharacteristicsA   = ma_dlsym(ma_context_get_log(pContext), pContext->wasapi.hAvrt, "AvSetMmThreadCharacteristicsA");
        pContext->wasapi.AvRevertMmThreadcharacteristics = ma_dlsym(ma_context_get_log(pContext), pContext->wasapi.hAvrt, "AvRevertMmThreadCharacteristics");

        /* If either function could not be found, disable use of avrt entirely. */
        if (!pContext->wasapi.AvSetMmThreadCharacteristicsA || !pContext->wasapi.AvRevertMmThreadcharacteristics) {
            pContext->wasapi.AvSetMmThreadCharacteristicsA   = NULL;
            pContext->wasapi.AvRevertMmThreadcharacteristics = NULL;
            ma_dlclose(ma_context_get_log(pContext), pContext->wasapi.hAvrt);
            pContext->wasapi.hAvrt = NULL;
        }
    }


    /*
    Annoyingly, WASAPI does not allow you to release an IAudioClient object from a different thread
    than the one that retrieved it with GetService(). This can result in a deadlock in two
    situations:

        1) When calling ma_device_uninit() from a different thread to ma_device_init(); and
        2) When uninitializing and reinitializing the internal IAudioClient object in response to
           automatic stream routing.

    We could define ma_device_uninit() such that it must be called on the same thread as
    ma_device_init(). We could also just not release the IAudioClient when performing automatic
    stream routing to avoid the deadlock. Neither of these are acceptable solutions in my view so
    we're going to have to work around this with a worker thread. This is not ideal, but I can't
    think of a better way to do this.

    More information about this can be found here:

        https://docs.microsoft.com/en-us/windows/win32/api/audioclient/nn-audioclient-iaudiorenderclient

    Note this section:

        When releasing an IAudioRenderClient interface instance, the client must call the interface's
        Release method from the same thread as the call to IAudioClient::GetService that created the
        object.
    */
    {
        result = ma_mutex_init(&pContext->wasapi.commandLock);
        if (result != MA_SUCCESS) {
            return result;
        }

        result = ma_semaphore_init(0, &pContext->wasapi.commandSem);
        if (result != MA_SUCCESS) {
            ma_mutex_uninit(&pContext->wasapi.commandLock);
            return result;
        }

        result = ma_thread_create(&pContext->wasapi.commandThread, ma_thread_priority_normal, 0, ma_context_command_thread__wasapi, pContext, &pContext->allocationCallbacks);
        if (result != MA_SUCCESS) {
            ma_semaphore_uninit(&pContext->wasapi.commandSem);
            ma_mutex_uninit(&pContext->wasapi.commandLock);
            return result;
        }
    }


    pCallbacks->onContextInit             = ma_context_init__wasapi;
    pCallbacks->onContextUninit           = ma_context_uninit__wasapi;
    pCallbacks->onContextEnumerateDevices = ma_context_enumerate_devices__wasapi;
    pCallbacks->onContextGetDeviceInfo    = ma_context_get_device_info__wasapi;
    pCallbacks->onDeviceInit              = ma_device_init__wasapi;
    pCallbacks->onDeviceUninit            = ma_device_uninit__wasapi;
    pCallbacks->onDeviceStart             = ma_device_start__wasapi;
    pCallbacks->onDeviceStop              = ma_device_stop__wasapi;
    pCallbacks->onDeviceRead              = ma_device_read__wasapi;
    pCallbacks->onDeviceWrite             = ma_device_write__wasapi;
    pCallbacks->onDeviceDataLoop          = NULL;
    pCallbacks->onDeviceDataLoopWakeup    = ma_device_data_loop_wakeup__wasapi;

    return MA_SUCCESS;
}
#endif

int main() {
    std::cout << "Hello, World!" << std::endl;
    return 0;
}
