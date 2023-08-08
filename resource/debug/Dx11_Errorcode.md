# DirectX 11 Error Matrix

-----


| DirectX 11 Error Code |                                           DirectX 11 ID |                                                                                                                                                                                                                                                                       DirectX 11 Description |
|----------------------:|--------------------------------------------------------:|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------:|
|            0x887C0002 |                              D3D11_ERROR_FILE_NOT_FOUND |                                                                                                                                                                                                                                                                       The file was not found |
|            0x887C0001 |               D3D11_ERROR_TOO_MANY_UNIQUE_STATE_OBJECTS |                                                                                                                                                                                                                     There are too many unique instances of a particular type of state object |
|            0x887C0003 |                D3D11_ERROR_TOO_MANY_UNIQUE_VIEW_OBJECTS |                                                                                                                                                                                                                      There are too many unique instances of a particular type of view object | 
|            0x887C0004 |D3D11_ERROR_DEFERRED_CONTEXT_MAP_WITHOUT_INITIAL_DISCARD |                                                                                                           The first call to ID3D11DeviceContext::Map after either ID3D11Device::CreateDeferredContext or ID3D11DeviceContext::FinishCommandList per Resource was not D3D11_MAP_WRITE_DISCARD | 
|            0x80004005 |                                                  E_FAIL |                                                                                                                                                                                                     Attempted to create a device with the debug layer enabled and the layer is not installed |
|            0x80070057 |                                            E_INVALIDARG |                                                                                                                                                                                                                                    An invalid parameter was passed to the returning function |
|            0x8007000E |                                           E_OUTOFMEMORY |                                                                                                                                                                                                                           Direct3D could not allocate sufficient memory to complete the call |
|            0x80004001 |                                               E_NOTIMPL |                                                                                                                                                                                                                      The method call isn't implemented with the passed parameter combination | 
|                   0x1 |                                                 S_FALSE |                                                                                                                                                                         Alternate success value, indicating a successful but nonstandard completion (the precise meaning depends on context) | 
|            0x887A002B |                                DXGI_ERROR_ACCESS_DENIED |                                                                                                          You tried to use a resource to which you did not have the required access privileges. This error is most typically caused when you write to a shared resource with read-only access |
|            0x887A0026 |                                  DXGI_ERROR_ACCESS_LOST |                                                                                                                         The desktop duplication interface is invalid. The desktop duplication interface typically becomes invalid when a different type of image is displayed on the desktop |
|            0x887A0036 |                               DXGI_ERROR_ALREADY_EXISTS |                                                                                                                                             The desired element already exists. This is returned by DXGIDeclareAdapterRemovalSupport if it is not the first time that the function is called |
|            0x887A002A |                       DXGI_ERROR_CANNOT_PROTECT_CONTENT |                                                                                                        DXGI can't provide content protection on the swap chain. This error is typically caused by an older driver, or when you use a swap chain that is incompatible with content protection |
|            0x887A0006 |                                  DXGI_ERROR_DEVICE_HUNG |                                                                                                                                     The application's device failed due to badly formed commands sent by the application. This is an design-time issue that should be investigated and fixed |
|            0x887A0005 |            "DX11 ERROR_CODE : DXGI_ERROR_DEVICE_REMOVED |                                           The video card has been physically removed from the system, or a driver upgrade for the video card has occurred. The application should destroy and recreate the device. For help debugging the problem, call ID3DXXDevice::GetDeviceRemovedReason |
|            0x887A0007 |                                 DXGI_ERROR_DEVICE_RESET |                                                                                                                                                            The device failed due to a badly formed command. This is a run-time issue; The application should destroy and recreate the device |
|            0x887A0020 |                        DXGI_ERROR_DRIVER_INTERNAL_ERROR |                                                                                                                                                                                                                   The driver encountered a problem and was put into the device removed state |
|            0x887A000B |                    DXGI_ERROR_FRAME_STATISTICS_DISJOINT |                                                                                                                                                                                                   An event (for example, a power cycle) interrupted the gathering of presentation statistics |
|            0x887A000C |                 DXGI_ERROR_GRAPHICS_VIDPN_SOURCE_IN_USE |                                                                                                               The application attempted to acquire exclusive ownership of an output, but failed because some other application (or device within the application) already acquired ownership |
|            0x887A0001 |                                 DXGI_ERROR_INVALID_CALL |                                                                                                                                                                          The application provided invalid parameter data; this must be debugged and fixed before the application is released |
|            0x887A0003 |                                    DXGI_ERROR_MORE_DATA |                                                                                                                                                                                                          The buffer supplied by the application is not big enough to hold the requested data |
|            0x887A002C |                          DXGI_ERROR_NAME_ALREADY_EXISTS |                                                                                                                                                               The supplied name of a resource in a call to IDXGIResource1::CreateSharedHandle is already associated with some other resource |
|            0x887A0021 |                                 DXGI_ERROR_NONEXCLUSIVE |                                                                                                                                                                                        A global counter resource is in use, and the Direct3D device can't currently use the counter resource |
|            0x887A0022 |                      DXGI_ERROR_NOT_CURRENTLY_AVAILABLE |                                                                                                                                                                                                      The resource or request is not currently available, but it might become available later |
|            0x887A0002 |                                    DXGI_ERROR_NOT_FOUND | When calling IDXGIObject::GetPrivateData, the GUID passed in is not recognized as one previously passed to IDXGIObject::SetPrivateData or IDXGIObject::SetPrivateDataInterface. When calling IDXGIFactory::EnumAdapters or IDXGIAdapter::EnumOutputs, the enumerated ordinal is out of range | 
|            0x887A0029 |                     DXGI_ERROR_RESTRICT_TO_OUTPUT_STALE |                                                                                                                                                                                      The DXGI output (monitor) to which the swap chain content was restricted is now disconnected or changed |
|            0x887A002D |                        DXGI_ERROR_SDK_COMPONENT_MISSING |                                                                                                                                                                                                                      The operation depends on an SDK component that is missing or mismatched | 
|            0x887A0028 |                         DXGI_ERROR_SESSION_DISCONNECTED |                                                                                                                                                                                                                                The Remote Desktop Services session is currently disconnected |
|            0x887A0004 |                                  DXGI_ERROR_UNSUPPORTED |                                                                                                                                                                                                                     The requested functionality is not supported by the device or the driver |
|            0x887A0027 |                                 DXGI_ERROR_WAIT_TIMEOUT |                                                                                                                                                                                                                    The time-out interval elapsed before the next desktop frame was available |
|            0x887A000A |                            DXGI_ERROR_WAS_STILL_DRAWING |                                                                                                                                                                   The GPU was busy at the moment when a call was made to perform an operation, and did not execute or schedule the operation |

----