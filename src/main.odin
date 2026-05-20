package main

import "core:fmt"
import "core:os"
import "base:runtime"
import win "core:sys/windows"

APP_NAME    :: "switcherit"
APP_VERSION :: #config(SWITCHERIT_VERSION, "dev")

WM_TRAY           :: win.WM_APP + 1
ID_TRAY_ENABLE    :: 1001
ID_TRAY_VERSION   :: 1002
ID_TRAY_EXIT      :: 1004
ID_TRAY_ICON      :: 1

LLKHF_INJECTED    :: 0x00000010

h_hook: win.HHOOK
main_window: win.HWND
tray_icon: win.HICON
enabled := true
debug_enabled := false
caps_processed := false
shift_caps_active := false

// Win32 bindings not exposed by core:sys/windows in this Odin version
HKL :: rawptr

GUITHREADINFO :: struct {
	cbSize:        u32,
	flags:         u32,
	hwndActive:    win.HWND,
	hwndFocus:     win.HWND,
	hwndCapture:   win.HWND,
	hwndMenuOwner: win.HWND,
	hwndMoveSize:  win.HWND,
	hwndCaret:     win.HWND,
	rcCaret:       win.RECT,
}

foreign import user32 "system:user32.lib"
foreign user32 {
	GetGUIThreadInfo   :: proc(thread_id: u32, info: ^GUITHREADINFO) -> win.BOOL ---
	GetKeyboardLayout   :: proc(thread_id: u32) -> HKL ---
	GetKeyboardLayoutList :: proc(buffer_count: i32, list: [^]HKL) -> i32 ---
	ActivateKeyboardLayout :: proc(layout: HKL, flags: u32) -> HKL ---
	GetAsyncKeyState     :: proc(v_key: i32) -> i16 ---
}

foreign import kernel32 "system:kernel32.lib"
foreign kernel32 {
	CreateMutexW :: proc(attributes: rawptr, initial_owner: win.BOOL, name: win.wstring) -> win.HANDLE ---
}

main :: proc() {
	args := os.args

	if len(args) > 1 && args[1] == "--version" {
		fmt.println(APP_NAME, APP_VERSION)
		return
	}

	for arg in args[1:] {
		if arg == "--debug" {
			debug_enabled = true
		}
	}

	mutex := CreateMutexW(nil, false, wide_ptr(APP_NAME))
	if win.GetLastError() == win.ERROR_ALREADY_EXISTS {
		show_message("Another instance of switcherit is already running!", APP_NAME)
		return
	}
	defer win.CloseHandle(mutex)

	register_window_class()
	main_window = create_message_window()
	if main_window == nil {
		show_message("Could not create switcherit message window.", "switcherit Error")
		return
	}
	defer win.DestroyWindow(main_window)

	tray_icon = create_tray_icon()
	defer destroy_tray_icon()

	if !add_tray_icon(main_window) {
		show_message("Could not add switcherit tray icon.", "switcherit Error")
		return
	}
	defer remove_tray_icon(main_window)

	h_hook = win.SetWindowsHookExW(win.WH_KEYBOARD_LL, low_level_keyboard_proc, nil, 0)
	if h_hook == nil {
		show_message("Error calling SetWindowsHookExW.", "switcherit Error")
		return
	}
	defer win.UnhookWindowsHookEx(h_hook)

	log("started; enabled=%v", enabled)

	// Clean up all temporary allocations made during startup
	free_all(context.temp_allocator)

	msg: win.MSG
	for win.GetMessageW(&msg, nil, 0, 0) != 0 {
		win.TranslateMessage(&msg)
		win.DispatchMessageW(&msg)
		// Safely free all temporary allocations made during message handling
		free_all(context.temp_allocator)
	}
}

register_window_class :: proc() {
	wc := win.WNDCLASSW {
		lpfnWndProc = window_proc,
		hInstance = cast(win.HANDLE)win.GetModuleHandleW(nil),
		lpszClassName = wide_ptr("switcheritTrayWindow"),
	}
	win.RegisterClassW(&wc)
}

create_message_window :: proc() -> win.HWND {
	return win.CreateWindowExW(
		0,
		wide_ptr("switcheritTrayWindow"),
		wide_ptr(APP_NAME),
		0,
		0,
		0,
		0,
		0,
		win.HWND_MESSAGE,
		nil,
		cast(win.HANDLE)win.GetModuleHandleW(nil),
		nil,
	)
}

window_proc :: proc "stdcall" (hwnd: win.HWND, msg: u32, wparam: win.WPARAM, lparam: win.LPARAM) -> win.LRESULT {
	context = runtime.default_context()

	switch msg {
	case WM_TRAY:
		if lparam == win.WM_RBUTTONUP || lparam == win.WM_CONTEXTMENU {
			show_tray_menu(hwnd)
		} else if lparam == win.WM_LBUTTONDBLCLK {
			enabled = !enabled
			update_tray_icon(hwnd)
		}
		return 0
	case win.WM_COMMAND:
		switch loword(wparam) {
		case ID_TRAY_ENABLE:
			enabled = !enabled
			update_tray_icon(hwnd)
		case ID_TRAY_VERSION:
			show_message(fmt.tprintf("%s %s", APP_NAME, APP_VERSION), APP_NAME)
		case ID_TRAY_EXIT:
			win.PostQuitMessage(0)
		}
		return 0
	case win.WM_DESTROY:
		win.PostQuitMessage(0)
		return 0
	}
	return win.DefWindowProcW(hwnd, msg, wparam, lparam)
}

show_tray_menu :: proc(hwnd: win.HWND) {
	menu := win.CreatePopupMenu()
	if menu == nil do return
	defer win.DestroyMenu(menu)

	enable_text := "Disable switcherit" if enabled else "Enable switcherit"
	append_menu(menu, ID_TRAY_ENABLE, enable_text)
	append_menu(menu, ID_TRAY_VERSION, "Version")
	append_menu(menu, ID_TRAY_EXIT, "Exit")

	pt: win.POINT
	win.GetCursorPos(&pt)
	win.SetForegroundWindow(hwnd)
	win.TrackPopupMenu(menu, win.TPM_RIGHTBUTTON, pt.x, pt.y, 0, hwnd, nil)
}

append_menu :: proc(menu: win.HMENU, id: uint, text: string) {
	win.AppendMenuW(menu, 0, uintptr(id), wide_ptr(text))
}

add_tray_icon :: proc(hwnd: win.HWND) -> bool {
	data := tray_data(hwnd)
	return win.Shell_NotifyIconW(win.NIM_ADD, &data) != false
}

update_tray_icon :: proc(hwnd: win.HWND) {
	data := tray_data(hwnd)
	win.Shell_NotifyIconW(win.NIM_MODIFY, &data)
}

remove_tray_icon :: proc(hwnd: win.HWND) {
	data := tray_data(hwnd)
	win.Shell_NotifyIconW(win.NIM_DELETE, &data)
}

tray_data :: proc(hwnd: win.HWND) -> win.NOTIFYICONDATAW {
	data: win.NOTIFYICONDATAW
	data.cbSize = size_of(win.NOTIFYICONDATAW)
	data.hWnd = hwnd
	data.uID = 1
	data.uFlags = win.NIF_MESSAGE | win.NIF_ICON | win.NIF_TIP
	data.uCallbackMessage = WM_TRAY
	data.hIcon = tray_icon

	tip := "switcherit - enabled" if enabled else "switcherit - disabled"
	copy_wide_to_fixed(&data.szTip, tip)
	return data
}

create_tray_icon :: proc() -> win.HICON {
	width := win.GetSystemMetrics(win.SM_CXSMICON)
	height := win.GetSystemMetrics(win.SM_CYSMICON)

	icon := win.LoadImageW(cast(win.HANDLE)win.GetModuleHandleW(nil), resource_ptr(ID_TRAY_ICON), win.IMAGE_ICON, width, height, 0)
	if icon != nil {
		return cast(win.HICON)icon
	}

	icon = win.LoadImageW(nil, wide_ptr("assets\\switcherit-tray.ico"), win.IMAGE_ICON, width, height, win.LR_LOADFROMFILE)
	if icon != nil {
		return cast(win.HICON)icon
	}

	and_mask: [32]u8
	xor_mask: [32]u8

	for i in 0..<len(xor_mask) {
		xor_mask[i] = 0xff
	}

	return win.CreateIcon(nil, 16, 16, 1, 1, cast(^win.BYTE)&and_mask[0], cast(^win.BYTE)&xor_mask[0])
}

destroy_tray_icon :: proc() {
	if tray_icon != nil {
		win.DestroyIcon(tray_icon)
		tray_icon = nil
	}
}

low_level_keyboard_proc :: proc "stdcall" (n_code: i32, wparam: win.WPARAM, lparam: win.LPARAM) -> win.LRESULT {
	context = runtime.default_context()

	key := cast(^win.KBDLLHOOKSTRUCT)uintptr(lparam)
	if n_code == win.HC_ACTION && key != nil {
		if (key.flags & LLKHF_INJECTED) != 0 {
			return win.CallNextHookEx(h_hook, n_code, wparam, lparam)
		}

		if key.vkCode == win.VK_CAPITAL {
			is_shift_down := GetAsyncKeyState(win.VK_SHIFT) < 0

			if wparam == win.WM_KEYDOWN || wparam == win.WM_SYSKEYDOWN {
				if is_shift_down {
					shift_caps_active = true
				} else {
					shift_caps_active = false
				}
			}

			if shift_caps_active {
				if wparam == win.WM_KEYUP || wparam == win.WM_SYSKEYUP {
					shift_caps_active = false
				}
				return win.CallNextHookEx(h_hook, n_code, wparam, lparam)
			}

			if wparam == win.WM_SYSKEYDOWN && !caps_processed {
				caps_processed = true
				enabled = !enabled
				log("Alt+CapsLock: enabled=%v", enabled)
				update_tray_icon(main_window)
				return 1
			}

			if wparam == win.WM_KEYDOWN && !caps_processed {
				caps_processed = true
			}

			if wparam == win.WM_KEYUP || wparam == win.WM_SYSKEYUP {
				caps_processed = false

				if enabled {
					log("CapsLock released: switching layout")
					switch_keyboard_layout()
				}
			}

			if !enabled {
				return win.CallNextHookEx(h_hook, n_code, wparam, lparam)
			}

			return 1
		}
	}

	return win.CallNextHookEx(h_hook, n_code, wparam, lparam)
}

switch_keyboard_layout :: proc() {
	next_layout := get_next_keyboard_layout()
	if next_layout == nil {
		log("switch aborted: no next layout")
		return
	}

	target := get_input_target_window()
	log("switch target=%x next_hkl=%x lang=%04x", uintptr(target), uintptr(next_layout), layout_language_id(next_layout))
	if target != nil {
		result := win.SendMessageW(target, win.WM_INPUTLANGCHANGEREQUEST, 0, cast(win.LPARAM)uintptr(next_layout))
		log("WM_INPUTLANGCHANGEREQUEST result=%d", result)
	} else {
		ActivateKeyboardLayout(next_layout, 0)
	}
}

get_next_keyboard_layout :: proc() -> HKL {
	count := GetKeyboardLayoutList(0, nil)
	log("layout count=%d", count)
	if count <= 1 do return nil

	layouts := make([]HKL, count)
	defer delete(layouts)

	read := GetKeyboardLayoutList(count, raw_data(layouts))
	log("layout read=%d", read)
	if read <= 1 do return nil

	target := get_input_target_window()
	thread_id: u32
	if target != nil {
		thread_id = win.GetWindowThreadProcessId(target, nil)
	}

	current := GetKeyboardLayout(thread_id)
	log("foreground=%x thread=%d current_hkl=%x lang=%04x primary=%03x", uintptr(target), thread_id, uintptr(current), layout_language_id(current), primary_language_id(current))
	for i in 0..<read {
		log("layout[%d]=%x lang=%04x primary=%03x", i, uintptr(layouts[i]), layout_language_id(layouts[i]), primary_language_id(layouts[i]))
	}

	for i in 0..<read {
		if layouts[i] == current {
			return next_primary_language_layout(layouts[:read], primary_language_id(current))
		}
	}

	log("current layout not found in list; using first layout")
	return layouts[0]
}

get_input_target_window :: proc() -> win.HWND {
	foreground := win.GetForegroundWindow()
	if foreground == nil do return nil

	thread_id := win.GetWindowThreadProcessId(foreground, nil)
	info := GUITHREADINFO {
		cbSize = size_of(GUITHREADINFO),
	}

	if GetGUIThreadInfo(thread_id, &info) {
		log("gui thread info: foreground=%x thread=%d active=%x focus=%x caret=%x", uintptr(foreground), thread_id, uintptr(info.hwndActive), uintptr(info.hwndFocus), uintptr(info.hwndCaret))
		if info.hwndFocus != nil do return info.hwndFocus
		if info.hwndActive != nil do return info.hwndActive
	}

	log("gui thread info unavailable: foreground=%x thread=%d", uintptr(foreground), thread_id)
	return foreground
}

next_primary_language_layout :: proc(layouts: []HKL, current_primary: u16) -> HKL {
	first_layouts := make([dynamic]HKL, 0, len(layouts))
	defer delete(first_layouts)

	for layout in layouts {
		primary := primary_language_id(layout)
		exists := false
		for first in first_layouts {
			if primary_language_id(first) == primary {
				exists = true
				break
			}
		}

		if !exists {
			append(&first_layouts, layout)
			log("primary group[%d]=%x lang=%04x primary=%03x", len(first_layouts) - 1, uintptr(layout), layout_language_id(layout), primary)
		}
	}

	if len(first_layouts) <= 1 do return nil

	for i in 0..<len(first_layouts) {
		if primary_language_id(first_layouts[i]) == current_primary {
			next := first_layouts[(i + 1) % len(first_layouts)]
			next_index := (i + 1) % len(first_layouts)
			log("selected primary group[%d]=%x lang=%04x primary=%03x", next_index, uintptr(next), layout_language_id(next), primary_language_id(next))
			return next
		}
	}

	log("current primary not found in primary groups; using first primary group")
	return first_layouts[0]
}

layout_language_id :: proc(layout: HKL) -> u16 {
	return u16(uintptr(layout) & 0xffff)
}

primary_language_id :: proc(layout: HKL) -> u16 {
	return layout_language_id(layout) & 0x03ff
}

current_exe_path :: proc() -> string {
	buffer: [win.MAX_PATH]u16
	n := win.GetModuleFileNameW(nil, &buffer[0], win.MAX_PATH)
	if n == 0 do return ""
	s, _ := win.wstring_to_utf8(cast(win.wstring)&buffer[0], int(n))
	return s
}

show_message :: proc(message: string, title: string) {
	win.MessageBoxW(nil, wide_ptr(message), wide_ptr(title), win.MB_OK)
}

log :: proc(format: string, args: ..any) {
	if !debug_enabled do return
	fmt.println(fmt.tprintf(format, ..args))
}

loword :: proc(value: win.WPARAM) -> uint {
	return uint(value & 0xffff)
}

copy_wide_to_fixed :: proc(dst: ^[128]u16, text: string) {
	w := cast([^]u16)win.utf8_to_wstring(text, context.temp_allocator)
	if w == nil {
		dst^[0] = 0
		return
	}
	i := 0
	for i < len(dst^) - 1 && w[i] != 0 {
		dst^[i] = w[i]
		i += 1
	}
	dst^[i] = 0
}

wide_ptr :: proc(s: string) -> win.wstring {
	return win.utf8_to_wstring(s, context.temp_allocator)
}

resource_ptr :: proc(id: uint) -> win.wstring {
	return cast(win.wstring)cast([^]u16)uintptr(id)
}
