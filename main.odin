package main
import "core:fmt"

import "core:thread"
import "core:sys/windows"
import "core:mem/virtual"

import "base:runtime"
import "base:intrinsics"

import "/journey"

WND_CALLBACK :: proc "stdcall" (window_handle : windows.HWND, message : windows.UINT, w_param : windows.WPARAM, l_param : windows.LPARAM) -> windows.LRESULT{
	switch message{
		case windows.WM_DESTROY:
		{
			windows.PostQuitMessage(0)
		}
	}

	return windows.DefWindowProcW(window_handle, message, w_param, l_param)
}


main ::  proc()  {
	///////////////////////// Initialization /////////////////////////
	
	global_arena: virtual.Arena
	err := virtual.arena_init_static(&global_arena) //we will change reserve and commit size later.

	input_event : windows.HANDLE = windows.CreateEventW(nil, windows.TRUE, windows.FALSE, nil)

	input_thread := thread.create(journey.InputEntryPoint)
	input_thread.data = &input_event

	thread.start(input_thread)

	////////////////////// Win32 Initialization /////////////////////////
	wclass_name := raw_data([]u16{74, 111, 117, 114, 110, 101, 121, 67, 108, 97, 115, 115, 0})
	w_name := raw_data([]u16{79, 100, 105, 110, 32, 74, 111, 117, 114, 110, 101, 121, 0})

	hinstance : windows.HINSTANCE = windows.HINSTANCE(windows.GetModuleHandleW(nil))

	display_info : windows.DEVMODEW

	windows.EnumDisplaySettingsW(nil, windows.ENUM_CURRENT_SETTINGS, &display_info)
	
	window_class : windows.WNDCLASSEXW = windows.WNDCLASSEXW{
		cbSize = size_of(windows.WNDCLASSEXW),
		lpfnWndProc = WND_CALLBACK,
		hInstance = hinstance, 	
		lpszClassName = wclass_name,
	}
	
	windows.RegisterClassExW(&window_class) 

	window_handle := windows.CreateWindowExW(
		0,
		wclass_name,
		w_name,
		0,
		(i32(display_info.dmPelsWidth) - journey.SCREEN_RESOLUTION.x) >> 1,
		(i32(display_info.dmPelsHeight) - journey.SCREEN_RESOLUTION.y) >> 1,
		journey.SCREEN_RESOLUTION.x,
		journey.SCREEN_RESOLUTION.y,
		nil,
		nil,
		hinstance,
		nil,
	)

	windows.SetCursor(nil)
	windows.ShowWindow(window_handle,windows.SW_NORMAL)

	msg : windows.MSG

	//We will use GetMessageW for blocking to avoid spin wait.
	for{
		ret_code := windows.GetMessageW(&msg,nil, 0x0, 0x0)

		if ret_code == 0{
			break
		}

		windows.DispatchMessageW(&msg)
	}

	windows.SetEvent(input_event)

	thread.destroy(input_thread)

	windows.CloseHandle(input_event)
	windows.DestroyWindow(window_handle)	
}
