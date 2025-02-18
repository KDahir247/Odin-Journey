#ifndef JOURNEY_AUDIO_LIBRARY_H
#define JOURNEY_AUDIO_LIBRARY_H



//TODO: -[T]khal -----------------------------------------------------------------------------------
/*
2024-12-23 create the ja_WinMem struct for holding proc ptr to VirtualAlloc2 and equivalent calls. [Complete]
2024-12-23 swap out windows HANDLE for an opaque handle type. the type will be a QWORD to capture the pointer size. [Complete]
2024-12-23 create the structure for the allocation. Type of allocation: static arena, static circular buffer  [Complete]
  2024-12-29 fold the JA_InitContext parameter into descriptors. We don't need ja_Context as well7. We can just index the static allocator. [Complete]
2024-12-29 verify that InitContext work and rename. [Complete]
2024-01-02 stub out Init Device where we initialize the device but not play it. [Complete] 
2024-01-02 create a structure for the device initialization to pass to the engine. [Complete]
2024-01-06 fix the clang warning (123 warning) and confine coding to C99 ISO  [Complete] "only -Wunused-parameter"
2024-01-18 Work on uninitialize device procedure. [Complete]
2024-01-18 Test if the functions work in odin. [Complete]
2024-01-18 Work on the decoder. We want to read up on the WAV and OGG documentation specs. We need to fetch the audio info for both WAV and OGG (we might also read up on MP3) [Partial Complete (WAV)]
2024-01-26 Disassemble JA_GetComAllocator, InitBackend, and InitDevice.
2024-01-26 Complete the WAV parse procedure. [We need deinit to close handle on the decoder (should be simple 2 CloseHandle call)]
2024-01-29 memory operation (memcpy, memmove, memcmp, etc....) Using compiler builtin [Complete] 
2024-02-01 Move the Wav parser struct with the other struct. [Complete]
2024-02-02 Just a thought.... Should we use NT (ntdll, user-mode) rather than kernel (kernel32). Kernel call to NT
2024-02-02 read up on https://learn.microsoft.com/en-us/windows/win32/fileio/i-o-completion-ports before using async. [Complete]
2024-02-02 read up on https://learn.microsoft.com/en-us/windows-hardware/drivers/kernel/overview-of-the-windows-i-o-model before finishing up on the decoder. [Complete]
2024-02-17 Read up on the vorbis ogg file format and specifications before working on any OGG procedures.
2024-02-17 Work on InitDecoderOGG procedure
*/


/*
      We want to use the correct audio category so it maps to the correct audio mode resulting in the best APO is used on the stream in the audio engine.
We want the audio signal to be mapped to the correct audio modes defined by the driver to provide the best user experience.

Should we use Real-Time Work Queue API or MFCreateMFByteStreamOnStreamEx, msdn is recommending it, instead of using threads. https://learn.microsoft.com/en-us/windows-hardware/drivers/audio/low-latency-audio
To avoid interference with non audio subsystems

    msdn
Also note that Desktop applications cannot use the offloading capabilities of audio adapters that support hardware-offloaded audio. These applications can still render audio, but only through the host pin which makes use of the software audio engine.

who will be responsible for setting up the  architecture of the library, such as rtwq (if used)
who will be responsible for rerouting (It seem like the device would be the best, since we want to get the new device and it has nothing to do with buffer or mixing nor the backend side of things)

InitBackend (responsible for creating the ring buffer,static allocator for the mixer in the engine and a buffer for streaming read, and possible another static allocator for the allocation that occur during setup, setup the dynamic linking)
InitDevice (responsible for getting the target endpoint device and for setting it up, and rerouting)
InitEngine (resampling, mixing and other buffer related things)

All DSP node struct will be 64 bytes size.

Big idea for DSP effect should it be cached? By this i mean that the computation is done once. Then it save the computation using a specific key to store in a stream in a file by using some_name.ext:key. Then we can move out all the WAV file and use this cache audio file for playing all the audio in the game.
    
Avoid extremely large IO read, rather do chunk reads It is benefitial for System file cache and the CPU cache. (Remember don't depend on the L3 cache this is a victim cache)

Don't use SetFilePointer for Async IO.

Intresting so in AMD there are perferred core, so avoid setting processor affinity or mask affinity which may interfere with favored core scheduling.

Look at the sync! is waitforobject faster then mutex (mutex may call MwaitX instruction which is fast) for Mutex we can use the SWRLock from msdn.
    
    */


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
* The client must open the stream in the mix format that is currently in use by the audio engine (or a format that is similar to the mix format)
* The audio engine's input streams and the output mix from the engine are all in this format
* The audio engine can mix only PCM streams.
* Channel count is either 1 or 2
* The Audio format is WAVE_FORMAT_PCM (integer) or WAVE_FORMAT_IEEE_FLOAT (floating)
* The common precision of the audio format is 16 (integer) and 32 (floating point)
    * We will use Wide (W) for msdn procedure, since odin lang only has wide procedure call of windows and we don't want to mash ansi and wide or do conversions if required.
*Drivers can use the low latency DDIs to report the supported sizes of the buffer that is used to transfer data between Windows and the hardware. Data transfers don't have to always use 10-ms buffers, as they did in previous Windows versions. Instead, the driver can specify if it can use small buffers, for example, 5 ms, 3 ms, 1 ms, etc.
*
    *
* Query the buffer size from driver in wasapi  and use that. Don't predefine and create a random size buffer.
    * Integer I16, float 32
* We will not downsample the audio for example from f32 to I16, but we may up sample the audio from S8 to I16 or from S8 to F32 thus we don't need to account for dithering, only is supported upsampling.
* Stream routing will be supported? (switching devices on play
* The audio engine can convert between a standard PCM sample size used by the application and the floating-point samples that the engine uses for its internal processing, but not sample rate, channel count and other important audio information.
* The GetMixFormat method retrieves the stream format that the audio engine uses for its internal processingbvb of shared-mode streams. The method always uses a WAVEFORMATEXTENSIBLE structure, instead of a stand-alone WAVEFORMATEX structure, to specify the format.
*The mix format that the audio engine uses for its internal processing of shared-mode streams is closely related to, but is not necessarily identical to, the stream format that the audio endpoint device uses in shared mode. Through the Windows multimedia control panel (Mmsys.cpl)
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

#include <immintrin.h>
#include <emmintrin.h>
#include <stdio.h>
////////////////////////////////////// TYPES //////////////////////////////////////

typedef unsigned long long QWORD;
typedef unsigned long DWORD;
typedef unsigned short WORD;
typedef unsigned char BYTE;
typedef const WORD * P16;
typedef const char * P8;

typedef DWORD BOOL32;
typedef QWORD BOOL64;

typedef float SINGLE;
typedef double DOUBLE;

typedef long long S64;
typedef long S32;
typedef short S16;

////////////////////////////////////// CORE //////////////////////////////////////

#define JA_LFORCE_INLINE static inline
#define IMPORT __declspec(dllimport)
#define JA_WINAPI __stdcall
#define JA_ALIGN(x) __attribute__ ((__aligned__ (x)))

#define JA_BYTE ((QWORD)(1))
#define JA_KILOBYTE ((QWORD(1) << 10)
#define JA_MEGABYTE ((QWORD)(1) << 20)
#define JA_GIGABYTE ((QWORD)(1) << 30)
#define JA_TERABYTE ((QWORD)(1) << 40)

#define JA_LOCAL static
#define JA_GLOBAL static

#define JA_MememoryCopy __builtin_memcpy_inline
#define JA_MemorySet __builtin_memset_inline
#define JA_MemoryCompare __builtin_memcmp_inline

///////////////////////////////////// WIN32 //////////////////////////////////////
#define JA_SUCCESS 0x00000000
#define JA_OVER_COMMITED_PAGE 0x00000004

#define JA_COINIT_DEFAULT 0x0000000C /* COINIT_MULTITHREADED |  COINIT_DISABLE_OLE1DDE | COINIT_SPEED_OVER_MEMORY */

//The IAudioClient object is not initialized.
#define JA_AUDIOCLNT_NOT_INITIALIZED 0x88890001

//The IAudioClient object is already initialized.
#define JA_AUDIOCLNT_ALREADY_INITIALIZED 0x88890002

//The AUDCLNT_STREAMFLAGS_LOOPBACK flag is set but the endpoint device is a capture device, not a rendering device.
#define JA_AUDIOCLNT_WRONG_ENDPOINT_TYPE 0x88890003

//The audio endpoint device has been unplugged, or the audio hardware or associated hardware resource has been reconfigured, disabled, removed or otherwise made unavailable for use.
#define JA_AUDIOCLNT_DEVICE_INVALIDATED 0x88890004

//The audio stream was not stopped at the time of the start call.
#define JA_AUDIOCLNT_NOT_STOPPED 0x88890005

//The NumFrameRequested value exceeds the available buffer space (buffer size - padding size)
#define JA_AUDIOCLNT_BUFFER_TO_LARGE 0x88890006

//The previous IAudioRenderClient::GetBuffer procedure call is still in effect.
#define JA_AUDIOCLNT_OUT_OF_ORDER 0x88890007

//The audio engine doesn't support the specified format.
#define JA_AUDIOCLNT_UNSUPPORTED_FORMAT 0x88890008

//The NumFramesWritten value exceeds the NumFrameRequested value specified in the previous IAudioRenderClient::GetBuffer procedure call.
#define JA_AUDIOCLNT_INVALID_SIZE 0x88890009

//The endpoint device is already in use. The device is being used in shared mode and the caller asked to use the device in exclusive or vis versa.
#define JA_AUDIOCLNT_DEVICE_IN_USE 0x8889000A

//Buffer cannot be accessed because a stream reset is in progress.
#define JA_AUDIOCLNT_BUFFER_OPERATION_PENDING 0x8889000B

//The thread is not registered.
#define JA_AUDIOCLNT_THREAD_NOT_REGISTERED 0x8889000C

//Indicates that the session spans more than one process.
#define JA_AUDIOCLNT_NO_SINGLE_PROCESS 0x8889000D

//The caller is requesting exclusive mode use of the endpoint device, but the user has disabled exclusive mode use of the device.
#define JA_AUDIOCLNT_EXLUSIVE_MODE_NOT_ALLOWED 0x8889000E

//The procedure failed to create the audio endpoint for either render or capture device. This occurs either if the audio endpoint device has been unplugged or the audio hardware or associated hardware resources have been tampered with
//(Reconfigured, disabled, removed, or otherwise made unavailable for use)
#define JA_AUDIOCLNT_ENDPOINT_CREATE_FAILED 0x8889000F

//The Windows audio service is not running.
#define JA_AUDIOCLNT_SERVICE_NOT_RUNNING 0x88890010

//The audio stream was not initialized for event-driven buffering.
#define JA_AUDIOCLNT_EVENTHANDLE_NOT_EXPECTED 0x88890011

//Exclusive mode only
#define JA_AUDIOCLNT_EXCLUSIVE_MODE_ONLY 0x88890012

//The AUDCLNT_STREAMFLAGS_EVENTCALLBACK flag is set but parameters hnsBufferDuration and hnsPeriodicity are not equal.
#define JA_AUDIOCLNT_BUFBURATION_PERIOD_NOT_EQUAL 0x88890013

//The audio stream is configured to use event-driven buffering, but the caller has not called IAudioClient::SetEventHandle to set the event handle on the stream.
#define JA_AUDIOCLNT_EVENTHANDLE_NOT_SET 0x88890014

//Indicates that the buffer has an incorrect size.
#define JA_AUDIOCLNT_INCORRECT_BUFFER_SIZE 0x88890015

//The audio endpoint device has been unplugged, or the audio hardware or associated hardware rIndicates that the process-pass duration exceeded the maximum CPU usage
#define JA_AUDIOCLNT_CPUUSAGE_EXCEEDED 0x88890017

//GetBuffer procedure failed to retrieve a data buffer and *ppData point to null.
#define JA_AUDIOCLNT_BUFFER_ERROR 0x88890018

//The requested buffer size is not aligned. Error may be returned from AUDCLNT_SHAREMODE_EXCLUSIVE and the AUDCLNT_STREAMFLAGS_EVENTCALLBACK flags.
#define JA_AUDIOCLNT_BUFFER_SIZE_NOT_ALIGNED 0x88890019

#define JA_STGM_READ 0x00000000L
#define JA_STGM_WRITE 0x00000001L
#define JA_STGM_READWRITE 0x00000002L

#define JA_MMCSS_CRITICAL 0x0000000000000002
#define JA_MMCSS_HIGH 0x0000000000000001
#define JA_MMCSS_NORMAL 0x0000000000000000
#define JA_MMCSS_LOW 0xFFFFFFFFFFFFFFFF
#define JA_MMCSS_VERYLOW 0xFFFFFFFFFFFFFFFE

#define JA_MEM_COMMIT 0x00001000
#define JA_MEM_RESERVE 0x00002000
#define JA_MEM_REPLACE_PLACEHOLDER 0x00004000
#define JA_MEM_RESERVE_PLACEHOLDER 0x00040000
#define JA_MEM_RESET 0x00080000
#define JA_MEM_RESET_UNDO 0x1000000

#define JA_MEM_DECOMMIT 0x00004000
#define JA_MEM_RELEASE 0x00008000
#define JA_COALESCE_PLACEHOLDERS 0x00000001
#define JA_MEM_PRESERVE_PLACEHOLDER 0x00000002

#define JA_FILE_MAP_ALL_ACCESS 0xF001F

#define JA_PAGE_NOACCESS 0x01
#define JA_PAGE_READONLY 0x02
#define JA_PAGE_READWRITE 0x04
#define JA_PAGE_WRITECOPY 0x08

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

#define JA_CLSCTX_ALL 0x00000017

#define JA_CREATE_EVENT_INITIAL_SET 0x00000002
#define JA_EVENT_MANUAL_RESET 0x00000001

#define JA_DELETE = 0x00010000
#define JA_READ_CONTROL 0x00020000
#define JA_SYNCHRONIZE 0x00100000
#define JA_WRITE_DAC 0x00040000
#define JA_WRITE_OWNER 0x00080000

#define JA_EVENT_ALL_ACCESS 0x1F0003
#define JA_EVENT_MODIFY_STATE 0x0002

#define JA_GUIDMatch  !JA_MemoryCompare

//IO
#define JA_GENERIC_ALL 0x10000000
#define JA_GENERIC_EXECUTE 0x20000000
#define JA_GENERIC_WRITE 0x40000000
#define JA_GENERIC_READ 0x80000000

#define JA_FILE_SHARE_DELETE 0x04
#define JA_FILE_SHARE_READ 0x01
#define JA_FILE_SHARE_WRITE 0x02

#define JA_CREATE_ALWAYS 0x02
#define JA_CREATE_NEW 0x01
#define JA_OPEN_ALWAYS 0x04
#define JA_OPEN_EXISTING 0x03
#define JA_TRUNCATE_EXISTING 0x05

#define JA_FILE_ATTRIBUTE_NORMAL 0x80
#define JA_FILE_ATTRIBUTE_ARCHIVE 0x20
#define JA_FILE_ATTRIBUTE_ENCRYPTED 0x4000
#define JA_FILE_ATTRIBUTE_HIDDEN 0x2
#define JA_FILE_ATTRIBUTE_OFFLINE 0x1000
#define JA_FILE_ATTRIBUTE_READONLY 0x1
#define JA_FILE_ATTRIBUTE_SYSTEM 0x4
#define JA_FILE_ATTRIBUTE_TEMPORARY 0x100


#define JA_FILE_FLAG_BACKUP_SEMANTICS 0x02000000
#define JA_FILE_FLAG_DELETE_ON_CLOSE 0x04000000
#define JA_FILE_FLAG_NO_BUFFERING 0x20000000
#define JA_FILE_FLAG_OPEN_NO_RECALL 0x00100000
#define JA_FILE_FLAG_OPEN_REPARSE_POINT 0x00200000
#define JA_FILE_FLAG_OVERLAPPED 0x40000000
#define JA_FILE_FLAG_POSIX_SEMANTICS 0x01000000
#define JA_FILE_FLAG_RANDOM_ACCESS 0x10000000
#define JA_FILE_FLAG_SESSION_AWARE 0x00800000
#define JA_FILE_FLAG_SEQUENTIAL_SCAN 0x08000000
#define JA_FILE_FLAG_WRITE_THROUGH 0x80000000

#define JA_FILE_BEGIN 0x00
#define JA_FILE_CURRENT 0x01
#define JA_FILE_END 0x02

#define JA_INFINITE 0xFFFFFFFF

///////////////////////////////////// FLAGS //////////////////////////////////////
#define JA_FLUSH_ZERO_ENABLE 0x00008000
#define JA_DENORMALS_ENABLE 0x00000040
#define JA_FLUSH_ZERO_DISABLE 0xFFFF7FFF
#define JA_DENORMALS_DISABLE 0xFFFFFFBF


/////////////////////////////////// ALLOCATOR ///////////////////////////////////
#define JA_DEFAULT_COMMIT (JA_MEGABYTE * 64)
#define JA_DEFAULT_RESERVE (JA_GIGABYTE * 6)
#define JA_DEFAULT_ALIGNMENT (1 << 3)
#define JA_PAGESIZE 4096
#define JA_ALLOCATION_GRANULARITY 65536


///////////////////////////////////// WASPI /////////////////////////////////////
#define JA_PrimarySampleRate 48000
#define JA_SecondarySampleRate 44100

#define JA_MinChannel 1
#define JA_MaxChannel 2

#define JA_WAVE_FORMAT_IEEE_FLOAT 0x0003
#define JA_WAVE_FORMAT_PCM 0x0001
#define JA_WAVE_FORMAT_EXTENSIBLE 0xFFFE

#define JA_FORM_FACTOR_REMOTENETWORKDEVICE 0x00000000
#define JA_FORM_FACTOR_SPEAKERS 0x00000001
#define JA_FORM_FACTOR_LINELEVEL 0x00000002
#define JA_FORM_FACTOR_HEADPHONE 0x00000003
#define JA_FORM_FACTOR_MICROPHONE 0x00000004
#define JA_FORM_FACTOR_HEADSET 0x00000005
#define JA_FORM_FACTOR_HANDSET 0x00000006
#define JA_FORM_FACTOR_UNKNOWN_DP 0x00000007
#define JA_FORM_FACTOR_SPDIF 0x00000008
#define JA_FORM_FACTOR_DADD 0x00000009
#define JA_FORM_FACTOR_UNKNOWN 0x0000000A

#define JA_ENDPOINT_SYSFX_ENABLED 0
#define JA_ENDPOINT_SYSFX_DISABLED 1

#define JA_AUDCLNT_STREAMFLAGS_CROSSPROCESS 0x00010000
#define JA_AUDCLNT_STREAMFLAGS_LOOPBACK 0x00020000
#define JA_AUDCLNT_STREAMFLAGS_EVENTCALLBACK 0x00040000
#define JA_AUDCLNT_STREAMFLAGS_NOPERSIST 0x00080000
#define JA_AUDCLNT_STREAMFLAGS_RATEADJUST 0x00100000
#define JA_AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM 0x80000000
#define JA_AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY 0x08000000

#define JA_DEVICE_STATE_ACTIVE 0x0000000000000001
#define JA_DEVICE_STATE_DISABLE 0x0000000000000002
#define JA_DEVICE_STATE_NOTPRESENT 0x0000000000000004
#define JA_DEVICE_STATE_UNPLUGGED 0x0000000000000008
#define JA_DEVICE_STATEMASK_ALL 0x000000000000000F

#define JA_EVENTCALLBACK_FLAG 0x00040000

//10ms
#define JA_DEFAULT_BUFFER_SIZE_NANOSECOND 10000000

//////////////////// Decoder ///////////////////////////////

#define JA_RIFF_MAGIC 1179011410
#define JA_FORM_MAGIC 1163280727

#define JA_FMT_CK_SEEK 0xCull
#define JA_DATA_CK_SEEK 0x2Cull
#define JA_HEADER_SIZE 12
#define JA_FMT_SIZE 24

typedef struct ja_GUID ja_GUID;
typedef struct ja_Blob ja_Blob;
typedef struct ja_GUID ja_IID;
typedef struct ja_PropVariant ja_PropVariant;
typedef struct ja_PropertyKey ja_PropertyKey;
typedef struct ja_MemExtendedParameter ja_MemExtendedParameter;
typedef struct ja_HandleO ja_HandleO;
typedef struct ja_Overlapped ja_Overlapped;
struct ja_HandleO{
    QWORD opaque;
};

struct ja_GUID{
    DWORD data_1;
    WORD data_2;
    WORD data_3;
    BYTE data_4[8];
};

struct ja_Blob{
    DWORD cb_size;
    BYTE * blob_data;
};


struct ja_PropVariant{
    WORD vt;
    WORD reserved_1;
    WORD reserved_2;
    WORD reserved_3;
    
    union{
        ja_Blob blob;
        DWORD dval;
        //Other data when needed refer to https://learn.microsoft.com/en-us/windows/win32/api/propidlbase/ns-propidlbase-propvariant
        BYTE padding[16];
    };
};

struct ja_PropertyKey{
    struct ja_GUID fmt_id;
    DWORD pid;
};

struct ja_MemExtendedParameter{
    struct{
        QWORD type : 8;
        QWORD reserved : 56;
    };
    
    union{
        QWORD ulong_64;
        void * pointer;
        QWORD size;
        ja_HandleO handle;
        DWORD ulong;
    };
    
};

struct ja_Overlapped{
    QWORD * internal;
    QWORD * internal_high;
    DWORD offset;
    DWORD offset_high;
    ja_HandleO h_event;
};


typedef enum ja_VARENUM {
    VT_EMPTY = 0,
    VT_NULL = 1,
    VT_I2 = 2,
    VT_I4 = 3,
    VT_R4 = 4,
    VT_R8 = 5,
    VT_CY = 6,
    VT_DATE = 7,
    VT_BSTR = 8,
    VT_DISPATCH = 9,
    VT_ERROR = 10,
    VT_BOOL = 11,
    VT_VARIANT = 12,
    VT_UNKNOWN = 13,
    VT_DECIMAL = 14,
    VT_I1 = 16,
    VT_UI1 = 17,
    VT_UI2 = 18,
    VT_UI4 = 19,
    VT_I8 = 20,
    VT_UI8 = 21,
    VT_INT = 22,
    VT_UINT = 23,
    VT_VOID = 24,
    VT_HRESULT = 25,
    VT_PTR = 26,
    VT_SAFEARRAY = 27,
    VT_CARRAY = 28,
    VT_USERDEFINED = 29,
    VT_LPSTR = 30,
    VT_LPWSTR = 31,
    VT_RECORD = 36,
    VT_INT_PTR = 37,
    VT_UINT_PTR = 38,
    VT_FILETIME = 64,
    VT_BLOB = 65,
    VT_STREAM = 66,
    VT_STORAGE = 67,
    VT_STREAMED_OBJECT = 68,
    VT_STORED_OBJECT = 69,
    VT_BLOB_OBJECT = 70,
    VT_CF = 71,
    VT_CLSID = 72,
    VT_VERSIONED_STREAM = 73,
    VT_BSTR_BLOB = 0xfff,
    VT_VECTOR = 0x1000,
    VT_ARRAY = 0x2000,
    VT_BYREF = 0x4000,
    VT_RESERVED = 0x8000,
    VT_ILLEGAL = 0xffff,
    VT_ILLEGALMASKED = 0xfff,
    VT_TYPEMASK = 0xfff
}ja_VARENUM;


typedef enum ja_EDataFlow{
    eRender = 0,
    eCapture,
    eAll,
    EDataFlow_enum_count
}ja_EDataFlow;


typedef enum ja_ERole{
    eConsole = 0,
    eMulimedia,
    eCommunications,
    ERole_enum_count
}ja_ERole;

typedef enum ja_ShareMode{
    Shared,
    Exclusive,
}ja_ShareMode;

typedef enum ja_StreamCategory{
    Other = 0,
    ForegroundOnlyMedia,
    BackgroundCapableMedia,
    Communications,
    Alerts,
    SoundEffects,
    GameEffects,
    GameMedia,
    GameChat,
    Speech,
    Movie,
    Media,
}ja_StreamCategory;

typedef enum ja_StreamOptions{
    None = 0x0,
    Raw = 0x1,
    Match_format = 0x2,
    Ambisonics = 0x4,
}ja_StreamOptions;

typedef enum ja_AudioSessionState{
    Inactive = 0,
    Active = 1,
    Expired = 2,
}ja_AudioSessionState;

typedef enum ja_SessionDisconnectReason{
    DeviceRemoval = 0,
    ServerShutdown = 1,
    FormatChanged = 2,
    Logoff = 3,
    Disconnected = 4,
    ExclusiveModeOverrride = 5,
}ja_SessionDisconnectReason;

typedef struct ja_IUnknown ja_IUnknown;
typedef struct ja_WaveFormatex ja_WaveFormatex;
typedef struct ja_WaveFormatexExtensible ja_WaveFormatexExtensible;
typedef struct ja_IMMDeviceEnumerator ja_IMMDeviceEnumerator;
typedef struct ja_IMMDeviceCollection ja_IMMDeviceCollection;
typedef struct ja_IMMDevice ja_IMMDevice;
typedef struct ja_IMMNotificationClient ja_IMMNotificationClient;
typedef struct ja_IPropertyStore ja_IPropertyStore;
typedef struct ja_IAudioClient3 ja_IAudioClient3;
typedef struct ja_IAudioSessionControl2 ja_IAudioSessionControl2;
typedef struct ja_IAudioSessionControl ja_IAudioSessionControl;
typedef struct ja_IAudioSessionEvents ja_IAudioSessionEvents;
typedef struct ja_IAudioRenderClient ja_IAudioRenderClient;
typedef struct ja_IAudioCaptureClient ja_IAudioCaptureClient;
typedef struct ja_IAudioClock2 ja_IAudioClock2;
typedef struct ja_IMalloc ja_IMalloc;

struct ja_IUnknown{
    struct ja_IUnknownVtbl * lpVtbl;
};

typedef struct ja_IUnknownVtbl{
    DWORD (JA_WINAPI * JA_QueryInterface)(ja_IUnknown * self, const ja_IID * const riid, void ** ppvObject);
    DWORD (JA_WINAPI * JA_AddRef)(ja_IUnknown * self);
    DWORD (JA_WINAPI * JA_Release)(ja_IUnknown * self);
} ja_IUnknownVtbl;


typedef struct ja_WaveFormatex{
    WORD format_tag;
    WORD channels;
    DWORD samples_per_sec; //sample rate
    DWORD avg_byte_per_sec;
    WORD block_align;
    WORD bits_per_sample;
    WORD byte_size;
}ja_WaveFormatex;

typedef struct ja_WaveFormatexExtensible{
    ja_WaveFormatex format;
    
    union{
        WORD valid_bits_per_sample;
        WORD samples_per_block;
        WORD reserved;
    }samples;
    
    DWORD channel_mask;
    ja_GUID sub_format;
}ja_WaveFormatexExtensible;


typedef struct ja_AudioClientProperties{
    DWORD cbSize;
    DWORD bIsOffload;
    ja_StreamCategory eCategory;
    ja_StreamOptions Options;
}ja_AudioClientProperties;

struct ja_IMMDeviceEnumerator{
    struct ja_IMMDeviceEnumeratorVtbl * vtbl;
};

typedef struct ja_IMMDeviceEnumeratorVtbl{
    DWORD (JA_WINAPI * JA_QueryInterface)(ja_IMMDeviceEnumerator * self, const ja_IID * const riid, void ** ppvObject);
    DWORD (JA_WINAPI * JA_AddRef)(ja_IMMDeviceEnumerator * self);
    DWORD (JA_WINAPI * JA_Release)(ja_IMMDeviceEnumerator * self);
    
    DWORD (JA_WINAPI * JA_EnumAudioEndpoints)(ja_IMMDeviceEnumerator * self, ja_EDataFlow dataFlow, DWORD dwStateMask, ja_IMMDeviceCollection ** ppDevices);
    DWORD (JA_WINAPI * JA_GetDefaultAudioEndpoint)(ja_IMMDeviceEnumerator * self, ja_EDataFlow dataFlow,  ja_ERole role, ja_IMMDevice ** ppEndpoint);
    DWORD (JA_WINAPI * JA_GetDevice)(ja_IMMDeviceEnumerator * self,const P16 pwstrId, ja_IMMDevice ** ppDevice);
    DWORD (JA_WINAPI * JA_RegisterEndpointNotificationCallback)(ja_IMMDeviceEnumerator * self, ja_IMMNotificationClient * pClient);
    DWORD (JA_WINAPI * JA_UnregisterEndpointNotificationCallback)(ja_IMMDeviceEnumerator * self, ja_IMMNotificationClient * pClient);
    
} ja_IMMDeviceEnumeratorVtbl;


struct ja_IMMDeviceCollection{
    struct ja_IMMDeviceCollectionVtbl * vtbl;
};

typedef struct ja_IMMDeviceCollectionVtbl{
    DWORD (JA_WINAPI * JA_QueryInterface)(ja_IMMDeviceCollection * self, const ja_IID * const riid, void ** ppvObject);
    DWORD (JA_WINAPI * JA_AddRef)(ja_IMMDeviceCollection * self);
    DWORD (JA_WINAPI * JA_Release)(ja_IMMDeviceCollection * self);
    
    DWORD (JA_WINAPI * JA_GetCount)(ja_IMMDeviceCollection* self, DWORD * pcDevice);
    DWORD (JA_WINAPI * JA_Item)(ja_IMMDeviceCollection * self, DWORD nDevice, ja_IMMDevice ** ppDevice);
    
}ja_IMMDeviceCollectionVtbl;


struct ja_IMMDevice{
    struct ja_IMMDeviceVtbl * vtbl;
};

typedef struct ja_IMMDeviceVtbl{
    DWORD (JA_WINAPI * JA_QueryInterface)(ja_IMMDevice * self, const ja_IID * const riid, void ** ppvObject);
    DWORD (JA_WINAPI * JA_AddRef)(ja_IMMDevice * self);
    DWORD (JA_WINAPI * JA_Release)(ja_IMMDevice * self);
    
    
    DWORD (JA_WINAPI * JA_Activate)(ja_IMMDevice * self, const ja_IID * const ja_IID, DWORD dwClsCtx, ja_PropVariant * pActivationParams, void ** ppInterface);
    DWORD (JA_WINAPI * JA_OpenPropertyStore)(ja_IMMDevice * self, DWORD stgmAccess, ja_IPropertyStore ** ppProperties);
    DWORD (JA_WINAPI * JA_GetId)(ja_IMMDevice * self, P16 * ppstrId);
    DWORD (JA_WINAPI * JA_GetState)(ja_IMMDevice * self, DWORD * pwState);
    
}ja_IMMDeviceVtbl;


struct ja_IMMNotificationClient{
    struct ja_IMMNotificationClientVtbl * vtbl;
    ja_IMMDeviceEnumerator * enumerator;
    ja_HandleO rerouting_handle;
    DWORD ref;
};

typedef struct ja_IMMNotificationClientVtbl{
    DWORD (JA_WINAPI * JA_QueryInterface)(ja_IMMNotificationClient * self, const ja_IID * const riid, void ** ppvObject);
    DWORD (JA_WINAPI * JA_AddRef)(ja_IMMNotificationClient * self);
    DWORD (JA_WINAPI * JA_Release)(ja_IMMNotificationClient * self);
    
    DWORD (JA_WINAPI * JA_OnDeviceStateChanged)(ja_IMMNotificationClient * self, const P16 pwstrDeviceId, DWORD dwNewState);
    DWORD (JA_WINAPI * JA_OnDeviceAdded)(ja_IMMNotificationClient * self, const P16 pwstrDeviceId);
    DWORD (JA_WINAPI * JA_OnDeviceRemoved)(ja_IMMNotificationClient * self, const P16 pwstrDeviceId);
    DWORD (JA_WINAPI * JA_OnDefaultDeviceChanged)(ja_IMMNotificationClient * self, ja_EDataFlow flow, ja_ERole role, const P16 pwstrDefaultDeviceId);
    DWORD (JA_WINAPI * JA_OnPropertyValueChanged)(ja_IMMNotificationClient * self, const P16 pwstrDeviceId, const ja_PropertyKey key);
    
}ja_IMMNotificationClientVtbl;


struct ja_IAudioSessionEvents{
    struct ja_IAudioSessionEventsVtbl * vtbl;
    ja_IAudioSessionControl * session;
    ja_HandleO rerouting_handle;
    DWORD ref;
};

typedef struct ja_IAudioSessionEventsVtbl{
    DWORD (JA_WINAPI * JA_QueryInterface)(ja_IAudioSessionEvents * self, const ja_IID * const riid, void ** ppvObject);
    DWORD (JA_WINAPI * JA_AddRef)(ja_IAudioSessionEvents * self);
    DWORD (JA_WINAPI * JA_Release)(ja_IAudioSessionEvents * self);
    
    DWORD (JA_WINAPI * JA_OnDisplayNameChanged)(ja_IAudioSessionEvents * self, const P16 NewDisplayName, const ja_GUID * EventContext);
    DWORD (JA_WINAPI * JA_OnIconPathChanged)(ja_IAudioSessionEvents * self, const P16 NewIconPath, const ja_GUID * EventContext);
    DWORD (JA_WINAPI * JA_OnSimpleVolumeChanged)(ja_IAudioSessionEvents * self, SINGLE NewVolume, DWORD NewMute, const ja_GUID * EventContext);
    DWORD (JA_WINAPI * JA_OnChannelVolumeChanged)(ja_IAudioSessionEvents * self, DWORD ChannelCount, SINGLE NewChannelVolumeArray[], DWORD ChangedChannel, const ja_GUID * EventContext);
    DWORD (JA_WINAPI * JA_OnGroupingParamChanged)(ja_IAudioSessionEvents * self, const ja_GUID * NewGroupingParam, const ja_GUID * EventContext);
    DWORD (JA_WINAPI * JA_OnStateChanged)(ja_IAudioSessionEvents *  self, ja_AudioSessionState NewState);
    DWORD (JA_WINAPI * JA_OnSessionDisconnected)(ja_IAudioSessionEvents * self, ja_SessionDisconnectReason DisconnectReason);
}ja_IAudioSessionEventsVtbl;


struct ja_IAudioSessionControl2{
    struct ja_IAudioSessionControl2Vtbl * vtbl;
};

typedef struct ja_IAudioSessionControl2Vtbl{
    DWORD (JA_WINAPI * JA_QueryInterface)(ja_IAudioSessionControl2 * self, const ja_IID * const riid, void ** ppvObject);
    DWORD (JA_WINAPI * JA_AddRef)(ja_IAudioSessionControl2 * self);
    DWORD (JA_WINAPI * JA_Release)(ja_IAudioSessionControl2 * self);
    
    //AudioSessionControl
    DWORD (JA_WINAPI * JA_GetState)(ja_IAudioSessionControl2 * self, ja_AudioSessionState * pRetVal);
    DWORD (JA_WINAPI * JA_GetDisplayName)(ja_IAudioSessionControl2 * self, P16 * pRetVal);
    DWORD (JA_WINAPI * JA_SetDisplayName)(ja_IAudioSessionControl2 * self, const P16 Value, const ja_GUID * EventContext);
    DWORD (JA_WINAPI * JA_GetIconPath)(ja_IAudioSessionControl2 * self, P16 * pRetVal);
    DWORD (JA_WINAPI * JA_SetIconPath)(ja_IAudioSessionControl2 * self, const P16 Value, const ja_GUID * EventContext);
    DWORD (JA_WINAPI * JA_GetGroupingParam)(ja_IAudioSessionControl2 * self, ja_GUID * pRetVal);
    DWORD (JA_WINAPI * JA_SetGroupingParam)(ja_IAudioSessionControl2 * self, const ja_GUID * Override, const ja_GUID * EventContext);
    DWORD (JA_WINAPI * JA_RegisterAudioSessionNotification)(ja_IAudioSessionControl2 * self, ja_IAudioSessionEvents * NewNotifications);
    DWORD (JA_WINAPI * JA_UnregisterAudioSessionNotification)(ja_IAudioSessionControl2 * self, ja_IAudioSessionEvents * NewNotifications);
    
    //AudioSessionControl2
    
    DWORD (JA_WINAPI * JA_GetSessionIdentifier)(ja_IAudioSessionControl2 * self, P16 * pRetVal);
    DWORD (JA_WINAPI * JA_GetSessionInstanceIdentifier)(ja_IAudioSessionControl2 * self, P16 * pRetVal);
    DWORD (JA_WINAPI * JA_GetProcessId)(ja_IAudioSessionControl2 * self, DWORD * pRetVal);
    DWORD (JA_WINAPI * JA_IsSystemSoundsSession)(ja_IAudioSessionControl2 * self);
    DWORD (JA_WINAPI * JA_SetDuckingPreference)(ja_IAudioSessionControl2 * self, DWORD optOut);
    
}ja_IAudioSessionControl2Vtbl;



struct ja_IAudioSessionControl{
    struct ja_IAudioSessionControlVtbl * vtbl;
};

typedef struct ja_IAudioSessionControlVtbl{
    DWORD (JA_WINAPI * JA_QueryInterface)(ja_IAudioSessionControl * self, const ja_IID * const riid, void ** ppvObject);
    DWORD (JA_WINAPI * JA_AddRef)(ja_IAudioSessionControl * self);
    DWORD (JA_WINAPI * JA_Release)(ja_IAudioSessionControl * self);
    
    DWORD (JA_WINAPI * JA_GetState)(ja_IAudioSessionControl * self, ja_AudioSessionState * pRetVal);
    DWORD (JA_WINAPI * JA_GetDisplayName)(ja_IAudioSessionControl * self, P16 * pRetVal);
    DWORD (JA_WINAPI * JA_SetDisplayName)(ja_IAudioSessionControl * self, const P16 Value, const ja_GUID * EventContext);
    DWORD (JA_WINAPI * JA_GetIconPath)(ja_IAudioSessionControl * self, P16 * pRetVal);
    DWORD (JA_WINAPI * JA_SetIconPath)(ja_IAudioSessionControl * self, const P16 Value, const ja_GUID * EventContext);
    DWORD (JA_WINAPI * JA_GetGroupingParam)(ja_IAudioSessionControl * self, ja_GUID * pRetVal);
    DWORD (JA_WINAPI * JA_SetGroupingParam)(ja_IAudioSessionControl * self, const ja_GUID * Override, const ja_GUID * EventContext);
    DWORD (JA_WINAPI * JA_RegisterAudioSessionNotification)(ja_IAudioSessionControl * self, ja_IAudioSessionEvents * NewNotifications);
    DWORD (JA_WINAPI * JA_UnregisterAudioSessionNotification)(ja_IAudioSessionControl * self, ja_IAudioSessionEvents * NewNotifications);
    
}ja_IAudioSessionControlVtbl;


struct ja_IPropertyStore{
    struct ja_IPropertyStoreVtbl * vtbl;
};

typedef struct ja_IPropertyStoreVtbl{
    DWORD (JA_WINAPI * JA_QueryInterface)(ja_IPropertyStore * self, const ja_IID * const riid, void ** ppvObject);
    DWORD (JA_WINAPI * JA_AddRef)(ja_IPropertyStore * self);
    DWORD (JA_WINAPI * JA_Release)(ja_IPropertyStore * self);
    
    DWORD (JA_WINAPI * JA_GetCount)(ja_IPropertyStore * self, DWORD * cProps);
    DWORD (JA_WINAPI * JA_GetAt)(ja_IPropertyStore * self, DWORD iProp, ja_PropertyKey * pKey);
    DWORD (JA_WINAPI * JA_GetValue)(ja_IPropertyStore * self, const ja_PropertyKey * const key, ja_PropVariant * pvariant);
    DWORD (JA_WINAPI * JA_SetValue)(ja_IPropertyStore * self, const ja_PropertyKey * const key, const ja_PropVariant * const propvar);
    DWORD (JA_WINAPI * ja_Commit)(ja_IPropertyStore * self);
    
}ja_IPropertyStoreVtbl;


struct ja_IAudioClient3{
    struct ja_IAudioClient3Vtbl * vtbl;
};


typedef struct ja_IAudioClient3Vtbl{
    DWORD (JA_WINAPI * JA_QueryInterface)(ja_IAudioClient3 * self, const ja_IID * const riid, void ** ppvObject);
    DWORD (JA_WINAPI * JA_AddRef)(ja_IAudioClient3 * self);
    DWORD (JA_WINAPI * JA_Release)(ja_IAudioClient3 * self);
    
    //IAudioClient
    DWORD (JA_WINAPI * JA_Initialize)(ja_IAudioClient3 * self, ja_ShareMode ShareMode, DWORD StreamingFlags, QWORD hnsBufferDuration, QWORD hnsPeriodicity, const ja_WaveFormatex * pFormat, const ja_GUID * AudioSessionGuid);
    DWORD (JA_WINAPI * JA_GetBufferSize)(ja_IAudioClient3 * self, DWORD * pNumBufferFrames);
    DWORD (JA_WINAPI * JA_GetStreamLatency)(ja_IAudioClient3 * self, QWORD * phnsLatency);
    DWORD (JA_WINAPI * JA_GetCurrentPadding)(ja_IAudioClient3 * self, DWORD * pNumPaddingFrames);
    DWORD (JA_WINAPI * JA_IsFormatSupported)(ja_IAudioClient3 * self, ja_ShareMode ShareMode, const ja_WaveFormatex * pFormat, ja_WaveFormatex ** ppClosestMatch);
    DWORD (JA_WINAPI * JA_GetMixFormat)(ja_IAudioClient3 * self, ja_WaveFormatex ** ppDeviceFormat);
    DWORD (JA_WINAPI * JA_GetDevicePeriod)(ja_IAudioClient3 * self, QWORD * phnsDefaultDevicePeriod, QWORD * phnsMinimumDevicePeriod);
    DWORD (JA_WINAPI * JA_Start)(ja_IAudioClient3 * self);
    DWORD (JA_WINAPI * JA_Stop)(ja_IAudioClient3 * self);
    DWORD (JA_WINAPI * JA_Reset)(ja_IAudioClient3 * self);
    
    DWORD (JA_WINAPI * JA_SetEventHandle)(ja_IAudioClient3 * self, ja_HandleO eventHandle);
    DWORD (JA_WINAPI * JA_GetService)(ja_IAudioClient3 * self, const ja_IID * const riid, void ** ppv);
    
    //IAudioClient2
    DWORD (JA_WINAPI * JA_IsOffloadingCapable)(ja_IAudioClient3 * self, ja_StreamCategory Category, DWORD *  pbOffloadCapable);
    DWORD (JA_WINAPI * JA_SetClientProperties)(ja_IAudioClient3 * self, const ja_AudioClientProperties * pProperties);
    DWORD (JA_WINAPI * JA_GetBufferSizeLimits)(ja_IAudioClient3 * self, const ja_WaveFormatex * pFormat, DWORD bEventDriven, QWORD * phnsMinBufferDuration, QWORD * phnsMaxBufferDuration);
    
    
    //IAudioClient3
    DWORD (JA_WINAPI * JA_GetSharedModeEnginePeriod)(ja_IAudioClient3 * self, const ja_WaveFormatex * pFormat, DWORD * pDefaultPeriodInFrames, DWORD * pFundamentalPeriodInFrames, DWORD * pMinPeriodInFrames, DWORD * pMaxPeriodInFrames);
    
    DWORD (JA_WINAPI * JA_GetCurrentSharedModeEnginePeriod)(ja_IAudioClient3 * self, ja_WaveFormatex ** ppFormat, DWORD * pCurrentPeriodInFrames);
    DWORD (JA_WINAPI * JA_InitializeSharedAudioStream)(ja_IAudioClient3 * self, DWORD StreamFlags, DWORD PeriodInFrames, const ja_WaveFormatex * pFormat, const ja_GUID * AudioSessionGuid);
}ja_IAudioClient3Vtbl;

struct ja_IAudioRenderClient{
    struct ja_IAudioRenderClientVtbl * vtbl;
};

typedef struct ja_IAudioRenderClientVtbl{
    DWORD (JA_WINAPI * JA_QueryInterface)(ja_IAudioRenderClient * self, const ja_IID * const riid, void ** ppvObject);
    DWORD (JA_WINAPI * JA_AddRef)(ja_IAudioRenderClient * self);
    DWORD (JA_WINAPI * JA_Release)(ja_IAudioRenderClient * self);
    
    DWORD (JA_WINAPI * JA_GetBuffer)(ja_IAudioRenderClient * self ,DWORD NumFramesRequested, BYTE ** ppData);
    DWORD (JA_WINAPI * JA_ReleaseBuffer)(ja_IAudioRenderClient * self, DWORD NumFramesWritten, DWORD dwFlags);
}ja_IAudioRenderClientVtbl;

struct ja_IAudioCaptureClient{
    struct ja_IAudioCaptureClientVtbl * vtbl;
};

typedef struct ja_IAudioCaptureClientVtbl{
    DWORD (JA_WINAPI * JA_QueryInterface)(ja_IAudioCaptureClient * self, const ja_IID * const riid, void ** ppvObject);
    DWORD (JA_WINAPI * JA_AddRef)(ja_IAudioCaptureClient * self);
    DWORD (JA_WINAPI * JA_Release)(ja_IAudioCaptureClient * self);
    
    DWORD (JA_WINAPI * JA_GetBuffer)(ja_IAudioCaptureClient * self, BYTE ** ppData, DWORD * pNumFramesToRead, DWORD * pdwFlags, QWORD * pu64DevicePosition, QWORD * pu64QPCPosition);
    DWORD (JA_WINAPI * JA_GetNextPacketSize)(ja_IAudioCaptureClient * self, DWORD * pNumFramesInNextPacket);
    DWORD (JA_WINAPI * JA_ReleaseBuffer)(ja_IAudioCaptureClient * self, DWORD NumFramesRead);
}ja_IAudioCaptureClientVtbl;

struct ja_IAudioClock2{
    struct ja_IAudioClock2Vtbl * vtbl;
};

typedef struct ja_IAudioClock2Vtbl{
    DWORD (JA_WINAPI * JA_QueryInterface)(ja_IAudioClock2 * self, const ja_IID * const riid, void ** ppvObject);
    DWORD (JA_WINAPI * JA_AddRef)(ja_IAudioClock2 * self);
    DWORD (JA_WINAPI * JA_Release)(ja_IAudioClock2 * self);
    
    //audio clock1
    DWORD (JA_WINAPI * JA_GetCharacteristics)(ja_IAudioClock2 * self, DWORD * pdwCharacteristics);
    DWORD (JA_WINAPI * JA_GetFrequency)(ja_IAudioClock2 * self, QWORD * pu64Frequency);
    DWORD (JA_WINAPI * JA_GetPosition)(ja_IAudioClock2 * self, QWORD * pu64Position, QWORD * pu64QPCPosition);
    
    //audio clock2
    DWORD (JA_WINAPI * JA_GetDevicePosition)(QWORD * DevicePosition, QWORD * QPCPosition);
}ja_IAudioClock2Vtbl;

struct ja_IMalloc{
    struct ja_IMallocVtbl * vtbl;
};

typedef struct ja_IMallocVtbl{
    DWORD (JA_WINAPI * JA_QueryInterface)(ja_IMalloc * self, const ja_IID * const riid, void ** ppvObject);
    DWORD (JA_WINAPI * JA_AddRef)(ja_IMalloc * self);
    DWORD (JA_WINAPI * JA_Release)(ja_IMalloc * self);
    
    void * (JA_WINAPI * JA_Alloc)(ja_IMalloc * self, QWORD size);
    BOOL32 (JA_WINAPI * JA_DidAlloc)(ja_IMalloc * self, void * pv);
    void (JA_WINAPI * JA_Free)(ja_IMalloc * self, void * pv);
    QWORD (JA_WINAPI * JA_GetSize)(ja_IMalloc * self, void * pv);
    void (JA_WINAPI * JA_HeapMinimize)(ja_IMalloc * self);
    void * (JA_WINAPI * JA_Realloc)(ja_IMalloc * self, void * pv, QWORD size);
}ja_IMallocVtbl;


static const ja_PropertyKey JA_PKEY_Device_FriendlyName = {{0xA45C254E, 0xDF1C, 0x4EFD, {0x80, 0x20, 0x67, 0xD1, 0x46, 0xA8, 0x50, 0xE0}}, 0x0E};

static const ja_PropertyKey JA_PKEY_AudioEngine_DeviceFormat = {{0xf19f064d,0x82c,0x4e27, {0xbc, 0x73, 0x68, 0x82, 0xa1, 0xbb, 0x8e, 0x4c}}, 0x0};
static const ja_PropertyKey JA_PKEY_AudioEngine_OEMFormat = {{0xe4870e26, 0x3cc5, 0x4cd2, {0xba, 0x46, 0xca, 0xa, 0x9a, 0x70, 0xed, 0x4}}, 0x03};

static const ja_PropertyKey JA_PKEY_AudioEndpoint_FormFactor = {{0x1da5d803, 0xd492, 0x4edd, {0x8c, 0x23, 0xe0, 0xc0, 0xff, 0xee, 0x7f, 0x0e}}, 0x00};
static const ja_PropertyKey JA_PKEY_AudioEndpoint_ControlPanelPageProvider = {{0x1da5d803, 0xd492, 0x4edd, {0x8c, 0x23, 0xe0, 0xc0, 0xff, 0xee, 0x7f, 0x0e}}, 0x01};
static const ja_PropertyKey JA_PKEY_AudioEndpoint_Association = {{0x1da5d803, 0xd492, 0x4edd, {0x8c, 0x23, 0xe0, 0xc0, 0xff, 0xee, 0x7f, 0x0e}}, 0x02};
static const ja_PropertyKey JA_PKEY_AudioEndpoint_PhysicalSpeakers = {{0x1da5d803, 0xd492, 0x4edd, {0x8c, 0x23, 0xe0, 0xc0, 0xff, 0xee, 0x7f, 0x0e}}, 0x03};
static const ja_PropertyKey JA_PKEY_AudioEndpoint_GUID = {{0x1da5d803, 0xd492, 0x4edd, {0x8c, 0x23, 0xe0, 0xc0, 0xff, 0xee, 0x7f, 0x0e}}, 0x04};
static const ja_PropertyKey JA_PKEY_AudioEndpoint_Disable_SysFx = {{0x1da5d803, 0xd492, 0x4edd, {0x8c, 0x23, 0xe0, 0xc0, 0xff, 0xee, 0x7f, 0x0e}}, 0x05};
static const ja_PropertyKey JA_PKEY_AudioEndpoint_FullRangeSpeakers = {{0x1da5d803, 0xd492, 0x4edd, {0x8c, 0x23, 0xe0, 0xc0, 0xff, 0xee, 0x7f, 0x0e}}, 0x06};
static const ja_PropertyKey JA_PKEY_AudioEndpoint_Supports_EventDriven_Mode = {{0x1da5d803, 0xd492, 0x4edd, {0x8c, 0x23, 0xe0, 0xc0, 0xff, 0xee, 0x7f, 0x0e}}, 0x07};
static const ja_PropertyKey JA_PKEY_AudioEndpoint_JackSubType = {{0x1da5d803, 0xd492, 0x4edd, {0x8c, 0x23, 0xe0, 0xc0, 0xff, 0xee, 0x7f, 0x0e}}, 0x08};
static const ja_PropertyKey JA_PKEY_AudioEndpoint_Default_VolumeInDb = {{0x1da5d803, 0xd492, 0x4edd, {0x8c, 0x23, 0xe0, 0xc0, 0xff, 0xee, 0x7f, 0x0e}}, 0x09};

static const ja_IID JA_IID_IUnknown = {0x00000000, 0x0000, 0x0000, {0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46}};
static const ja_IID JA_IDD_IAgileObject = {0x94EA2B94, 0xE9CC, 0x49E0, {0xC0, 0xFF, 0xEE, 0x64, 0xCA, 0x8F, 0x5B, 0x90}};

static const ja_IID JA_IID_IAudioClient = {0x1CB9AD4C, 0xDBFA, 0x4C32, {0xB1, 0x78, 0xC2, 0xF5, 0x68, 0xA7, 0x03, 0xB2}};
static const ja_IID JA_IID_IAudioClient2 = {0x726778CD, 0xF60A, 0x4EDA, {0x82, 0xDE, 0xE4, 0x76, 0x10, 0xCD, 0x78, 0xAA}};
static const ja_IID JA_IID_IAudioClient3 = {0x7ED4EE07, 0x8E67, 0x4CD4, {0x8C, 0x1A, 0x2B, 0x7A, 0x59, 0x87, 0xAD, 0x42}};

static const ja_IID JA_IID_IAudioRenderClient = {0xF294ACFC, 0x3146, 0x4483, {0xA7, 0xBF, 0xAD, 0xDC, 0xA7, 0xC2, 0x60, 0xE2}};
static const ja_IID JA_IID_IAudioCaptureClient = {0xC8ADBD64, 0xE71E, 0x48A0, {0xA4, 0xDE, 0x18, 0x5C, 0x39, 0x5C, 0xD3, 0x17}};
static const ja_IID JA_IID_IMMNotificationClient = {0x7991EEC9, 0x7E89, 0x4D85, {0x83, 0x90, 0x6C, 0x70, 0x3C, 0xEC, 0x60, 0xC0}};
static const ja_IID JA_IID_IAudioSessionEvents = {0x24918ACC, 0x64B3, 0x37C1, {0x8C, 0xA9, 0x74, 0xA6, 0x6E, 0x99, 0x57, 0xA8}};
static const ja_IID JA_IID_IAudioSessionControl2 = {0xBFB7FF88, 0x7239, 0x4FC9, {0x8F, 0xA2, 0x07, 0xC9, 0x50, 0xBE, 0x9C, 0x6D}};
static const ja_IID JA_IID_IAudioSessionControl = {0xF4B1A599, 0x7266, 0x4319, {0xA8, 0xCA, 0xE7, 0x0A, 0xCB, 0x11, 0xE8, 0xCD}};
static const ja_IID JA_IID_IAudioClock2 = {0x6F49FF73, 0x6727, 0x49AC, {0xA0, 0x08, 0xD9, 0x8C, 0xF5, 0xE7, 0x00, 0x48}};
static const ja_IID IID_DEV_INTERFACE_AUDIO_RENDER = {0xE6327CAD, 0xDCEC, 0x4949, {0xAE, 0x8A, 0x99, 0x1E, 0x97, 0x6A, 0x79, 0xD2}};
static const ja_IID IID_DEV_INTERFACE_AUDIO_CAPTURE = {0x2EEF81BE, 0x33FA, 0x4800, {0x96, 0x70, 0x1C, 0xD4, 0x74, 0x97, 0x2C, 0x3F}};

static const ja_IID JA_CLSID_MMDeviceEnumerator = {0xBCDE0395, 0xE52F, 0x467C, {0x8E, 0x3D, 0xC4, 0x57, 0x92, 0x91, 0x69, 0x2E}};
static const ja_IID JA_IID_IMMDeviceEnumerator = {0xA95664D2, 0x9614, 0x4F35, {0xA7, 0x46, 0xDE, 0x8D, 0xB6, 0x36, 0x17, 0xE6}};

static const ja_GUID JA_KSDATAFORMAT_SUBTYPE_PCM = {0x00000001, 0x0000, 0x0010, {0x80, 0x00, 0x00, 0xAA, 0x00, 0x38, 0x9B, 0x71}};
static const ja_GUID JA_KSDATA_FORMAT_SUBTYPE_IEEE_FLOAT = {0x00000003, 0x0000, 0x0010, {0x80, 0x00, 0x00, 0xAA, 0x00, 0x38, 0x9B, 0x71 } };

static const ja_HandleO JA_NULL_HANDLE = {0};
static const ja_HandleO JA_INVALID_HANDLE = {0xFFFFFFFFFFFFFFFF};

static ja_IMMNotificationClient ja_notification_client;
static ja_IAudioSessionEvents ja_session_event;

static ja_IMMNotificationClientVtbl notification_vtbl;
static ja_IAudioSessionEventsVtbl session_vtbl;

//Allocation

IMPORT void* JA_WINAPI 
MapViewOfFileEx(
                ja_HandleO hFileMappingObject,
                DWORD  dwDesiredAccess,
                DWORD  dwFileOffsetHigh,
                DWORD  dwFileOffsetLow,
                QWORD dwNumberOfBytesToMap,
                void * lpBaseAddress
                );

IMPORT BOOL32 JA_WINAPI 
VirtualLock(
            void* lpAddress,
            QWORD dwSize
            );

IMPORT BOOL32 JA_WINAPI
VirtualUnlock(
              void* lpAddress,
              QWORD dwSize
              );

IMPORT void* JA_WINAPI 
VirtualAlloc(
             void* lpAddress,
             QWORD dwSize,
             DWORD  flAllocationType,
             DWORD  flProtect
             );


IMPORT BOOL32 JA_WINAPI 
VirtualFree(
            void* lpAddress,
            QWORD dwSize,
            DWORD  dwFreeType
            );

IMPORT BOOL32 JA_WINAPI 
UnmapViewOfFile(
                const void* lpBaseAddress
                );

IMPORT ja_HandleO JA_WINAPI 
CreateFileMappingW(
                   ja_HandleO hFile,
                   void* lpFileMappingAttributes,
                   DWORD flProtect,
                   DWORD dwMaximumSizeHigh,
                   DWORD dwMaximumSizeLow,
                   const P16 lpName
                   );

//Lib loading

IMPORT ja_HandleO JA_WINAPI 
LoadLibraryW(
             const P16 lib_name
             );

IMPORT BOOL32 JA_WINAPI 
FreeLibrary(
            ja_HandleO lib_module
            );

IMPORT void* JA_WINAPI 
GetProcAddress(
               ja_HandleO lib_module,
               const P8 proc_name
               );

IMPORT BOOL32 JA_WINAPI 
CloseHandle(
            ja_HandleO handle
            );

//Sync
IMPORT ja_HandleO JA_WINAPI 
CreateEventExW(
               void * lpEventAttributes,
               const P16 lpName,
               DWORD dwFlags,
               DWORD dwDesiredAccess
               );


//File IO
IMPORT ja_HandleO JA_WINAPI
CreateFileW(
            const P16 lpFileName,
            DWORD dwDesiredAccess,
            DWORD dwShareMode,
            void * lpSecurityAttributes,
            DWORD dwCreationDisposition,
            DWORD dwFlagsAndAttributes,
            QWORD hTemplateFile
            );

IMPORT DWORD JA_WINAPI
GetFileSizeEx(
              ja_HandleO hFile,
              QWORD * lpFileSize
              );

IMPORT DWORD JA_WINAPI
ReadFile(
         ja_HandleO hFile,
         void * lpBuffer,
         DWORD nNumberOfBytesToRead,
         DWORD * lpNumberOfBytesRead,
         ja_Overlapped * lpOverlapped
         );


//TODO:Khal maybe also include ReadFileEx

IMPORT DWORD JA_WINAPI
SetFilePointerEx(
                 ja_HandleO hFile,
                 QWORD liDistanceToMove,
                 QWORD * lpNewFilePointer,
                 DWORD dwMoveMethod
                 );


IMPORT DWORD JA_WINAPI
WaitForSingleObject(
                    ja_HandleO hHandle,
                    DWORD dwMilliseconds
                    );

IMPORT DWORD JA_WINAPI
ResetEvent(
           ja_HandleO hEvent
           );

//Ole32
typedef DWORD (JA_WINAPI * CoInitializeEx)(void * pv_reserved, DWORD dw_coinit);
typedef DWORD (JA_WINAPI * CoCreateInstance)(const ja_IID * const ref_clsid, ja_IUnknown * unknown_outer, DWORD cls_context, const ja_IID * const iid, void * ppv);
typedef void (JA_WINAPI * CoUninitialize)(void);
typedef DWORD (JA_WINAPI * CoGetMalloc)(DWORD dwMemContext, ja_IMalloc ** ppMalloc);

//Avrt
typedef ja_HandleO (JA_WINAPI * AvSetMmThreadCharacteristicsW)(P16 task_name, DWORD * task_index);
typedef BOOL32 (JA_WINAPI * AvRevertMmThreadCharacteristics)(ja_HandleO avrt_handle);
typedef BOOL32 (JA_WINAPI * AvSetMmThreadPriority)(ja_HandleO avrt_handle, DWORD priority);


struct ja_WinCOM{
    ja_HandleO handle;
    CoInitializeEx ja_CoInitializeEx;
    CoCreateInstance ja_CoCreateInstance;
    CoUninitialize ja_CoUninitialize;
};

struct ja_WinAvrt{
    ja_HandleO handle;
    AvSetMmThreadCharacteristicsW ja_AvSetMmThreadCharacteristicsW;
    AvRevertMmThreadCharacteristics ja_AvRevertMmThreadCharacteristics;
};

struct ja_Proc{
    struct ja_WinCOM com;
    //struct ja_WinAvrt avrt;
};

//TODO:Khal should we make this an array of 64 function (IsNotPowerOfTwo, IsNotAligned)
JA_LFORCE_INLINE BOOL64
JA_IsNotPowerOfTwo(QWORD x){
    return (x & (x - 1));
}

JA_LFORCE_INLINE BOOL64
JA_IsNotAligned(QWORD x, const QWORD alignment){
    QWORD modulo = alignment - 1;
    
    return (x & modulo) | (alignment & modulo);
}

JA_LFORCE_INLINE QWORD
JA_RoundDownPowerTwo(QWORD x){
    x = x | (x >> 1);
    x = x | (x >> 2);
    x = x | (x >> 4);
    x = x | (x >> 8);
    x = x | (x >> 16);
    return x - (x >> 1);
}

JA_LFORCE_INLINE QWORD
JA_RoundUpPowerTwo(QWORD x){
    x = x -1;
    x = x | (x >> 1);
    x = x | (x >> 2);
    x = x | (x >> 4);
    x = x | (x >> 8);
    x = x | (x >> 16);
    return x + 1;
}

JA_LFORCE_INLINE QWORD
JA_Max(QWORD x, QWORD y){
    return x > y ? x : y;
}

JA_LFORCE_INLINE QWORD
JA_Min(QWORD x, QWORD y){
    return x < y ? x : y;
}

struct ja_StaticAllocator{
    QWORD offset;
    QWORD alignment;
    QWORD commit;
    QWORD reserved;
    QWORD _unused_[4];
};

JA_LFORCE_INLINE void *
JA_PushAllocate(struct ja_StaticAllocator * allocator, QWORD size){
    BYTE * allocation;
    QWORD alignment_diff;
    QWORD forward_alignment;
    
    //alignment check then push.
    alignment_diff = allocator->offset & (allocator->alignment - 1);
    forward_alignment = (allocator->alignment - alignment_diff) & 7;
    
    allocation = (BYTE *)(allocator) + allocator->offset + forward_alignment;
    allocator->offset += forward_alignment + size;
    
    return allocation;
}


JA_LFORCE_INLINE void
JA_PopAllocate(struct ja_StaticAllocator * allocator, QWORD size){
    allocator->offset -= size;
}

JA_LFORCE_INLINE void
JA_SetAlignerAllocate(struct ja_StaticAllocator * allocator, QWORD alignment){
    allocator->alignment = JA_Min(alignment, 8);
    
    if (JA_IsNotPowerOfTwo(alignment)){
        allocator->alignment = JA_RoundUpPowerTwo(alignment);
    }
}

JA_LFORCE_INLINE void
JA_ClearAllocate(struct ja_StaticAllocator * allocator){
    allocator->offset = sizeof(struct ja_StaticAllocator);
    
}

JA_LFORCE_INLINE struct ja_Proc *
JA_GetProcedure(struct ja_StaticAllocator * allocator){
    return (struct ja_Proc *)(allocator + 0x01);
}

struct ja_RingBuffer{
    void * buffer;
    QWORD size;
    QWORD write_index;
    QWORD read_index;
};

struct ja_Resource{
    struct ja_RingBuffer ring;
    struct ja_StaticAllocator * global_allocator;
    ja_IMalloc * com_allocator;
};

struct ja_MemoryDescriptor{
    DWORD static_reserve;
    DWORD static_commit;
    DWORD ring_size;
    DWORD _unused_;
};

struct ja_DeviceDescriptor{
    ja_EDataFlow flow;
    ja_ERole role;
    ja_StreamCategory category;
    DWORD periodicity;
};

struct ja_AudioDevice{
    ja_IAudioClient3 * audio_client;
    ja_IMMDevice * endpoint_device;
    
    ja_HandleO stream_handle;
    ja_HandleO stream_rerouting_handle;
    ja_HandleO quit_handle;
    
    DWORD max_buffer_size;
    DWORD format_tag;
    DWORD channels; 
    DWORD bits_per_sample;
    DWORD samples_per_second;
    SINGLE optimal_latency;
};

struct ja_RIFFMeta{
    DWORD ck_id;
    DWORD ck_size;
};

struct ja_RIFFHeader{
    DWORD ck_id;
    DWORD ck_size;
    DWORD form_type;
};

struct ja_WaveDecoderDescriptor{
    struct ja_StaticAllocator * allocator;
    QWORD frame_offset;
    DWORD frame_size;
    DWORD frame_count;
};

//OGG
struct ja_OggDecoderDescriptor{
    DWORD place_holder;
};

struct ja_Decoder{
    ja_HandleO fhandle;
    ja_HandleO async_handle;
    
    QWORD offset_frame;
    DWORD frame_chunk_size;
    DWORD frame_count;
    
    DWORD format_tag;
    DWORD channel;
    DWORD samples_per_sec;
    DWORD avg_bytes_per_sec; 
    DWORD block_align;
    DWORD bits_per_sample;
    DWORD sample_byte_size;
    DWORD _unused_;
};


/////////////////////////////////////// Proc  Signature //////////////////////////////////////////// 
ja_IMalloc *
JA_GetComAlloctor(void);

BOOL32
JA_InitBackend(const struct ja_MemoryDescriptor * mem_desc, struct ja_Resource *  res);

BOOL32
JA_InitDevice(const struct ja_DeviceDescriptor * desc, struct ja_Resource * res, struct ja_AudioDevice * device);

void
JA_DeinitDevice(struct ja_AudioDevice * device);

void
JA_InitDecoderWAV(const P16 wav_path, struct ja_WaveDecoderDescriptor * wav_desc, struct ja_Decoder* decoder);

void 
JA_InitDecoderOGG(const P16 vorbis_path, struct ja_OggDecoderDescriptor * ogg_desc, struct ja_Decoder* decoder);
////////////////////////////////////// Callback Events /////////////////////////////////////////////

JA_LOCAL DWORD JA_WINAPI 
JA_In_Session_QueryInterface(ja_IAudioSessionEvents * self, const ja_IID * const ref_iid, void ** object){
    
    //if(JA_GUIDMatch(ref_iid, &JA_IID_IUnknown) || JA_GUIDMatch(ref_iid, &JA_IID_IAudioSessionEvents)){
    
    //JA_In_Session_AddRef(self);
    //*object = self;
    
    //return 0;
    //}
    
    return 1;
}

JA_LOCAL DWORD JA_WINAPI 
JA_In_Session_AddRef(ja_IAudioSessionEvents * self){
    return (DWORD)(_InterlockedIncrement((long *)(&self->ref)));
}

JA_LOCAL DWORD JA_WINAPI  
JA_In_Session_Release(ja_IAudioSessionEvents * self){
    DWORD ref = (DWORD)(_InterlockedDecrement((long *)(&self->ref)));
    
    if (ref){
        return ref;
    }else{
        
    }
    
    
    //free(self); This will not work, since we are using our global allocator (linear)
    return 0;
}

JA_LOCAL DWORD JA_WINAPI
JA_In_Session_OnDisplayNameChanged(ja_IAudioSessionEvents * self, const P16 new_display_name, const ja_GUID * event_context){
    
    
    return 0;
}

JA_LOCAL DWORD JA_WINAPI
JA_In_Session_OnIconPathChanged(ja_IAudioSessionEvents * self, const P16 new_icon_path, const ja_GUID * event_context){
    
    
    return 0;
}


JA_LOCAL DWORD JA_WINAPI
JA_In_Session_OnSimpleVolumeChanged(ja_IAudioSessionEvents * self, SINGLE new_volume, DWORD new_mute, const ja_GUID * event_context ){
    
    return 0;
}

JA_LOCAL DWORD JA_WINAPI
JA_In_Session_OnChannelVolumeChanged(ja_IAudioSessionEvents * self, DWORD channel_count, SINGLE new_channel_volume_array[], DWORD changed_channel, const ja_GUID * event_context){
    
    return 0;
}

JA_LOCAL DWORD JA_WINAPI
JA_In_Session_OnGroupingParamChanged(ja_IAudioSessionEvents * self, const ja_GUID * new_grouping_param, const ja_GUID * event_context){
    
    return 0;
}

JA_LOCAL DWORD JA_WINAPI
JA_In_Session_OnStateChanged(ja_IAudioSessionEvents * self, ja_AudioSessionState new_state){
    
    
    return 0;
}

JA_LOCAL DWORD JA_WINAPI
JA_In_Session_OnSessionDisconnected(ja_IAudioSessionEvents * self, ja_SessionDisconnectReason disconnect_reason){
    
    return 0;
}


JA_LOCAL DWORD JA_WINAPI
JA_In_Noti_QueryInterface(ja_IMMNotificationClient * self, const ja_IID * const ref_iid, void ** object){
    
    //if (JA_GUIDMatch(ref_iid, &JA_IID_IUnknown) || JA_GUIDMatch(ref_iid, &JA_IID_IMMNotificationClient)){
    //JA_In_Noti_AddRef(self);
    //*object = self;
    //return 0;
    //}
    
    return 1;
}

JA_LOCAL DWORD JA_WINAPI
JA_In_Noti_AddRef(ja_IMMNotificationClient * self){
    return (DWORD)(_InterlockedIncrement((long*)(&self->ref)));
}

JA_LOCAL DWORD JA_WINAPI
JA_In_Noti_Release(ja_IMMNotificationClient * self){
    DWORD ref = (DWORD)(_InterlockedDecrement((long *)(&self->ref)));
    
    if (ref){
        return ref;
    }else{
        
    }
    
    return 0;
}

JA_LOCAL DWORD JA_WINAPI
JA_In_Noti_OnDeviceStateChange(ja_IMMNotificationClient * self, const P16 str_device_id, DWORD new_state){
    
    return 0;
}

JA_LOCAL DWORD JA_WINAPI
JA_In_Noti_OnDeviceAdded(ja_IMMNotificationClient * self, const P16 str_device_id){
    
    
    return 0;
}

JA_LOCAL DWORD JA_WINAPI
JA_In_Noti_OnDeviceRemoved(ja_IMMNotificationClient * self, const P16 str_device_id){
    
    
    return 0;
}

JA_LOCAL DWORD JA_WINAPI
JA_In_Noti_OnDefaultDeviceChanged(ja_IMMNotificationClient * self, ja_EDataFlow flow, ja_ERole role, const P16 str_default_device_id){
    
    return 0;
}

JA_LOCAL DWORD JA_WINAPI
JA_In_Noti_OnPropertyValueChanged(ja_IMMNotificationClient * self, const P16 str_device_id, const ja_PropertyKey key){
    
    return 0;
}


///////////////////////////// Initialization Device /////////////////////////////
ja_IMalloc *
JA_GetComAlloctor(void){
    ja_HandleO opaque_lib_handle;
    CoGetMalloc com_global_allocator;
    ja_IMalloc * com_alloc;
    
    opaque_lib_handle = LoadLibraryW(L"ole32.dll");
    
    com_global_allocator = (CoGetMalloc)GetProcAddress(opaque_lib_handle, "CoGetMalloc");
    com_global_allocator(1, &com_alloc);
    
    CloseHandle(opaque_lib_handle);
    opaque_lib_handle.opaque = 0;
    com_global_allocator = NULL;
    
    return com_alloc;
}


BOOL32
JA_InitBackend(const struct ja_MemoryDescriptor * mem_desc, struct ja_Resource *  res){
    struct ja_StaticAllocator * global_ptr;
    ja_IMalloc * com_alloc; 
    BYTE * ring_buffer;
    QWORD global_reservation_size;
    QWORD global_page_size;
    QWORD ring_buffer_backend_size;
    
    ring_buffer = NULL;
    
    global_reservation_size = ((mem_desc->static_reserve >> 16) + 1) << 16;
    global_page_size = ((mem_desc->static_commit >> 12) + 1) << 12;
    
    ring_buffer_backend_size = ((mem_desc->ring_size >> 16) + 1) << 16;
    
    global_ptr = VirtualAlloc(NULL, global_reservation_size, JA_MEM_RESERVE, JA_PAGE_READWRITE);
    global_ptr =  (struct ja_StaticAllocator*)VirtualAlloc(global_ptr, global_page_size, JA_MEM_COMMIT, JA_PAGE_READWRITE);
    
    //We need to specify the alignment before we actually push
    global_ptr->offset = sizeof(struct ja_StaticAllocator);
    global_ptr->alignment = JA_DEFAULT_ALIGNMENT;
    global_ptr->commit = global_page_size;
    global_ptr->reserved = global_reservation_size;
    
    {
        struct ja_Proc * dynamic_procedure;
        
        dynamic_procedure = (struct ja_Proc*)JA_PushAllocate(global_ptr, sizeof(struct ja_Proc));
        
        dynamic_procedure->com.handle = LoadLibraryW(L"ole32.dll");
        
        //ole32.dll (COM)
        dynamic_procedure->com.ja_CoInitializeEx = (CoInitializeEx)GetProcAddress(dynamic_procedure->com.handle, "CoInitializeEx");
        dynamic_procedure->com.ja_CoCreateInstance = (CoCreateInstance)GetProcAddress(dynamic_procedure->com.handle, "CoCreateInstance");
        dynamic_procedure->com.ja_CoUninitialize = (CoUninitialize)GetProcAddress(dynamic_procedure->com.handle, "CoUninitialize");
        
        {
            CoGetMalloc com_global_allocator;
            
            com_global_allocator = (CoGetMalloc)GetProcAddress(dynamic_procedure->com.handle, "CoGetMalloc");
            com_global_allocator(1, &com_alloc);
        }
        
        //TODO:Khal other function that we need that isn't a part of Kernel32. refer to (https://www.geoffchappell.com/studies/windows/win32/kernel32/api/index.htm)
        //proc->avrt.handle = JA_LoadLibrary(L"avrt.dll");
        
        //TODO:Khal maybe use rtwq rather then avrt.
        //avrt.dll (MMCSS)
        //proc->avrt.ja_AvSetMmThreadCharacteristicsW = (AvSetMmThreadCharacteristicsW)JA_GetProcAddress(proc->avrt.handle, "AvSetMmThreadCharacteristicsW");
        //proc->avrt.ja_AvRevertMmThreadCharacteristics = (AvRevertMmThreadCharacteristics)JA_GetProcAddress(proc->avrt.handle, "AvRevertMmThreadCharacteristics");
    }
    
    {
        ja_HandleO backend_mapping;
        BOOL32 stolen_mapping;
        
        stolen_mapping = 0;
        backend_mapping = CreateFileMappingW(JA_NULL_HANDLE, NULL, JA_PAGE_READWRITE, 0, (DWORD)(ring_buffer_backend_size), NULL);
        
        for(QWORD attempt = 0; attempt < 100; attempt++){
            
            ring_buffer = VirtualAlloc(NULL, ring_buffer_backend_size << 2, JA_MEM_RESERVE, JA_PAGE_NOACCESS);
            VirtualFree(ring_buffer, 0, JA_MEM_RELEASE);
            
            for (QWORD repetition_index = 0; repetition_index < 4; repetition_index++){
                if (!MapViewOfFileEx(backend_mapping,JA_FILE_MAP_ALL_ACCESS, 0, 0,ring_buffer_backend_size, ring_buffer + repetition_index * ring_buffer_backend_size)){
                    stolen_mapping = 1;
                    break;
                }
            }
            
            if (stolen_mapping){
                for (QWORD repetition_index = 0; repetition_index < 4; repetition_index++){
                    UnmapViewOfFile(ring_buffer + repetition_index * ring_buffer_backend_size);
                }
                continue;
            }
            
            break;
        }
        
    }
    
    {
        res->global_allocator = global_ptr;
        
        res->ring.buffer = ring_buffer;
        res->ring.size =  ring_buffer_backend_size;
        res->ring.write_index = 0;
        res->ring.read_index = 0;
        
        res->com_allocator = com_alloc;
    }
    
    return JA_SUCCESS;
}


BOOL32
JA_InitDevice(const struct ja_DeviceDescriptor * desc, struct ja_Resource * res, struct ja_AudioDevice * device){
    struct ja_Proc * procedure;
    
    ja_IMMDeviceEnumerator * device_enumerator;
    ja_IMMDevice * endpoint_device;
    ja_IAudioClient3 * audio_client;
    
    procedure = JA_GetProcedure(res->global_allocator);
    
    procedure->com.ja_CoInitializeEx(NULL, JA_COINIT_DEFAULT);
    procedure->com.ja_CoCreateInstance(&JA_CLSID_MMDeviceEnumerator, NULL, JA_CLSCTX_ALL, &JA_IID_IMMDeviceEnumerator,  (void **)(&device_enumerator));
    
    device_enumerator->vtbl->JA_GetDefaultAudioEndpoint(device_enumerator, desc->flow, desc->role, &endpoint_device);
    endpoint_device->vtbl->JA_Activate(endpoint_device, &JA_IID_IAudioClient3, 0x04, NULL,(void **)&audio_client);
    
    {
        ja_PropVariant prop_variant;
        ja_AudioClientProperties client_properties;
        ja_IPropertyStore * property_store;
        
        BOOL32 apo_enabled_mask;
        BOOL32 event_driven_mode_mask;
        BOOL32 apo_offloading_mask;
        
        endpoint_device->vtbl->JA_OpenPropertyStore(endpoint_device, JA_STGM_READ, &property_store);
        
        property_store->vtbl->JA_GetValue(property_store, &JA_PKEY_AudioEndpoint_Disable_SysFx, &prop_variant);
        apo_enabled_mask = ~prop_variant.dval & 0x00000001;
        
        property_store->vtbl->JA_GetValue(property_store, &JA_PKEY_AudioEndpoint_Supports_EventDriven_Mode, &prop_variant);
        event_driven_mode_mask = prop_variant.dval;
        
        if (apo_enabled_mask){
            audio_client->vtbl->JA_IsOffloadingCapable(audio_client, desc->category, &apo_offloading_mask);
            apo_enabled_mask &= apo_offloading_mask;
        }
        
        //Starting with Windows 10 hardware offloaded audio stream must be event driven.
        event_driven_mode_mask |= apo_enabled_mask;
        
        if (event_driven_mode_mask <= 0){
            device_enumerator->vtbl->JA_Release(device_enumerator);
            endpoint_device->vtbl->JA_Release(endpoint_device);
            audio_client->vtbl->JA_Release(audio_client);
            property_store->vtbl->JA_Release(property_store);
            
            //TODO:Khal handle if the audio endpoint doesn't support event driven mode.
            return 0;
        }
        
        client_properties.cbSize = sizeof(ja_AudioClientProperties);
        client_properties.bIsOffload = apo_enabled_mask;
        client_properties.eCategory = desc->category;
        client_properties.Options = None;
        
        audio_client->vtbl->JA_SetClientProperties(audio_client, &client_properties);
        
        property_store->vtbl->JA_Release(property_store);
    }
    
    
    {
        ja_WaveFormatex * audio_engine_format;
        
        DWORD default_period_in_frame;
        DWORD fundamental_period_in_frame;
        DWORD min_period_in_frame;
        DWORD max_period_in_frame;
        DWORD target_periodicity;
        DWORD periodicity_difference;
        
        audio_client->vtbl->JA_GetMixFormat(audio_client, &audio_engine_format);
        
        audio_client->vtbl->JA_GetSharedModeEnginePeriod(audio_client, audio_engine_format, &default_period_in_frame, &fundamental_period_in_frame, &min_period_in_frame, &max_period_in_frame);
        
        target_periodicity = desc->periodicity;
        periodicity_difference = desc->periodicity & (fundamental_period_in_frame - 1);
        
        if(periodicity_difference){
            target_periodicity += fundamental_period_in_frame - periodicity_difference;
        }
        
        target_periodicity = (DWORD)(JA_Min(JA_Max(target_periodicity, min_period_in_frame), max_period_in_frame));
        
        audio_client->vtbl->JA_InitializeSharedAudioStream(audio_client, JA_EVENTCALLBACK_FLAG, target_periodicity, audio_engine_format, NULL);
        
        res->com_allocator->vtbl->JA_Free(res->com_allocator, audio_engine_format);
    }
    
    
    {
        ja_WaveFormatex * current_format;
        DWORD current_period_in_frames;
        DWORD buffer_size;
        
        current_format = NULL;
        
        audio_client->vtbl->JA_GetCurrentSharedModeEnginePeriod(audio_client, &current_format, &current_period_in_frames);
        audio_client->vtbl->JA_GetBufferSize(audio_client, &buffer_size);
        
        device->audio_client = audio_client;
        device->endpoint_device = endpoint_device;
        
        device->stream_handle = CreateEventExW(NULL, NULL, 0, JA_SYNCHRONIZE | JA_EVENT_MODIFY_STATE);
        device->stream_rerouting_handle =  CreateEventExW(NULL, NULL, 0, JA_SYNCHRONIZE | JA_EVENT_MODIFY_STATE);
        device->quit_handle =  CreateEventExW(NULL, NULL, 0, JA_SYNCHRONIZE | JA_EVENT_MODIFY_STATE);
        
        device->max_buffer_size = buffer_size;
        
        device->format_tag = current_format->format_tag & 0x7;
        
        if (current_format->format_tag == JA_WAVE_FORMAT_EXTENSIBLE){
            ja_WaveFormatexExtensible * current_format_extended;
            
            current_format_extended = (ja_WaveFormatexExtensible *)current_format;
            
            
            device->format_tag = (current_format_extended->sub_format.data_1 >> 0x14) & 0x7;
            
        }
        
        device->channels = (DWORD)(current_format->channels);
        device->bits_per_sample = (DWORD)(current_format->bits_per_sample);
        device->samples_per_second = current_format->samples_per_sec;
        device->optimal_latency = (SINGLE)(current_period_in_frames)  / (SINGLE)(current_format->samples_per_sec);
        
        audio_client->vtbl->JA_SetEventHandle(audio_client, device->stream_handle);
        
        res->com_allocator->vtbl->JA_Free(res->com_allocator, current_format);
    }
    
    
    {
        
        //Initialize the statics
        ja_IAudioSessionControl * session_control;
        
        //We need to allocate the virtual table. We will use the COM malloc.
        
        audio_client->vtbl->JA_GetService(audio_client, &JA_IID_IAudioSessionControl,(void**)(&session_control));
        
        if(ja_notification_client.ref <= 0){
            ja_notification_client.vtbl = &notification_vtbl;
            
            ja_notification_client.vtbl->JA_QueryInterface = JA_In_Noti_QueryInterface;
            ja_notification_client.vtbl->JA_AddRef = JA_In_Noti_AddRef;
            ja_notification_client.vtbl->JA_Release = JA_In_Noti_Release;
            
            ja_notification_client.vtbl->JA_OnDeviceStateChanged = JA_In_Noti_OnDeviceStateChange;
            ja_notification_client.vtbl->JA_OnDeviceAdded = JA_In_Noti_OnDeviceAdded;
            ja_notification_client.vtbl->JA_OnDeviceRemoved = JA_In_Noti_OnDeviceRemoved;
            ja_notification_client.vtbl->JA_OnDefaultDeviceChanged = JA_In_Noti_OnDefaultDeviceChanged;
            ja_notification_client.vtbl->JA_OnPropertyValueChanged = JA_In_Noti_OnPropertyValueChanged;
            
            ja_notification_client.vtbl->JA_AddRef(&ja_notification_client);
        }
        
        if(ja_session_event.ref <= 0){
            ja_session_event.vtbl = &session_vtbl;
            
            ja_session_event.vtbl->JA_QueryInterface = JA_In_Session_QueryInterface;
            ja_session_event.vtbl->JA_AddRef = JA_In_Session_AddRef;
            ja_session_event.vtbl->JA_Release = JA_In_Session_Release;
            
            ja_session_event.vtbl->JA_OnDisplayNameChanged = JA_In_Session_OnDisplayNameChanged;
            ja_session_event.vtbl->JA_OnIconPathChanged = JA_In_Session_OnIconPathChanged;
            ja_session_event.vtbl->JA_OnSimpleVolumeChanged = JA_In_Session_OnSimpleVolumeChanged;
            ja_session_event.vtbl->JA_OnChannelVolumeChanged = JA_In_Session_OnChannelVolumeChanged;
            ja_session_event.vtbl->JA_OnGroupingParamChanged = JA_In_Session_OnGroupingParamChanged;
            ja_session_event.vtbl->JA_OnStateChanged = JA_In_Session_OnStateChanged;
            ja_session_event.vtbl->JA_OnSessionDisconnected = JA_In_Session_OnSessionDisconnected;
            
            ja_session_event.vtbl->JA_AddRef(&ja_session_event);
        }
        
        ja_notification_client.enumerator = device_enumerator;
        ja_notification_client.rerouting_handle = device->stream_rerouting_handle;
        
        ja_session_event.session = session_control;
        ja_session_event.rerouting_handle = device->stream_rerouting_handle;
        
        session_control->vtbl->JA_RegisterAudioSessionNotification(session_control, &ja_session_event);
        device_enumerator->vtbl->JA_RegisterEndpointNotificationCallback(device_enumerator, &ja_notification_client);
    }
    
    return JA_SUCCESS;
}

void
JA_DeinitDevice(struct ja_AudioDevice * device){
    {
        
        ja_IMMDeviceEnumerator * device_enumerator;
        ja_IAudioSessionControl * session_control;
        
        device_enumerator = ja_notification_client.enumerator;
        session_control = ja_session_event.session;
        
        ja_notification_client.vtbl->JA_Release(&ja_notification_client);
        ja_session_event.vtbl->JA_Release(&ja_session_event);
        
        //TODO:Khal Make the event vtbl null if ref count is zero.
        
        device_enumerator->vtbl->JA_UnregisterEndpointNotificationCallback(device_enumerator, &ja_notification_client);
        session_control->vtbl->JA_UnregisterAudioSessionNotification(session_control, &ja_session_event);
        
        device_enumerator->vtbl->JA_Release(device_enumerator);
        session_control->vtbl->JA_Release(session_control);
        
        device_enumerator = NULL;
        session_control = NULL;
    }
    
    {
        device->audio_client->vtbl->JA_Release(device->audio_client);
        device->endpoint_device->vtbl->JA_Release(device->endpoint_device);
        
        device->audio_client = NULL;
        device->endpoint_device = NULL;
        
        CloseHandle(device->stream_handle);
        CloseHandle(device->stream_rerouting_handle);
        CloseHandle(device->quit_handle);
        
        device->stream_handle.opaque = 0x0;
        device->stream_rerouting_handle.opaque = 0x0;
        device->quit_handle.opaque = 0x0;
    }
}

//TODO: Khal create DeinitSpatialDevice.
//TODO: Khal create InitializeSpatialDevice.


/////////////////////////// Decoder Procedure  ///////////////////////////

void
JA_InitDecoderWAV(const P16 wav_path, struct ja_WaveDecoderDescriptor * wav_desc, struct ja_Decoder* decoder){
    ja_HandleO decoder_handle;
    ja_HandleO async_io_handle;
    DWORD* file_data;
    
    file_data = (DWORD *)JA_PushAllocate(wav_desc->allocator, 48);
    
    {
        ja_Overlapped  overlapped;
        
        JA_MemorySet(&overlapped,0, sizeof(ja_Overlapped));
        
        async_io_handle = CreateEventExW(NULL, NULL, JA_EVENT_MANUAL_RESET, JA_SYNCHRONIZE | JA_EVENT_MODIFY_STATE );
        decoder_handle =  CreateFileW(wav_path, JA_GENERIC_READ, JA_FILE_SHARE_READ, NULL, JA_OPEN_EXISTING, (JA_FILE_ATTRIBUTE_NORMAL | JA_FILE_FLAG_SEQUENTIAL_SCAN) | (JA_FILE_ATTRIBUTE_READONLY | JA_FILE_FLAG_OVERLAPPED), 0);
        
        overlapped.h_event = async_io_handle;
        
        //Seem like passing overlapped will always make ReadFile async regardless if overlapped is passed.
        ReadFile(decoder_handle, file_data, 48, NULL, &overlapped);
    }
    
    //We use a full cache line for the decode, but not for the file_data.
    
    decoder->fhandle = decoder_handle;
    decoder->async_handle = async_io_handle;
    
    decoder->offset_frame = wav_desc->frame_offset;
    decoder->frame_chunk_size = wav_desc->frame_size;
    decoder->frame_count = wav_desc->frame_count;
    
    WaitForSingleObject(async_io_handle, JA_INFINITE);
    ResetEvent(async_io_handle);
    
    {
        decoder->format_tag = file_data[5] & 0x7F;
        decoder->channel = (file_data[5] >> 0x10) & 0x7F;
        
        decoder->samples_per_sec = file_data[6];
        decoder->avg_bytes_per_sec = file_data[7];
        
        decoder->block_align = file_data[8] & 0x7F;
        decoder->bits_per_sample = (file_data[8] >> 0x10) & 0x7F;
        decoder->sample_byte_size = file_data[10];
    }
}

void 
JA_InitDecoderOGG(const P16 vorbis_path, struct ja_OggDecoderDescriptor * ogg_desc, struct ja_Decoder* decoder){
    
    //TODO:Khal implement me
}



///////////////////////// Permutation Procedure //////////////////////////

//This will be SIMD heavy, due to high computation requirement. Also I will try to make it multithreaded. (DSP permutations, eg. lowpass, reverb, mixing, etc....)



///////////////////////////// Audio Engine /////////////////////////////

#endif //JOURNEY_AUDIO_LIBRARY_H
