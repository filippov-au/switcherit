package main

import "core:fmt"
import "core:os"
import "base:runtime"
import win "core:sys/windows"

APP_NAME    :: "switcherit"
APP_VERSION :: #config(SWITCHERIT_VERSION, "dev")

WM_APP            :: 0x8000
WM_TRAY           :: WM_APP + 1
WM_COMMAND        :: 0x0111
WM_DESTROY        :: 0x0002
WM_INPUTLANGCHANGEREQUEST :: 0x0050
WM_CONTEXTMENU    :: 0x007B
WM_RBUTTONUP      :: 0x0205
WM_LBUTTONDBLCLK  :: 0x0203
WM_KEYDOWN        :: 0x0100
WM_KEYUP          :: 0x0101
WM_SYSKEYDOWN     :: 0x0104
WM_SYSKEYUP       :: 0x0105

HC_ACTION         :: 0
WH_KEYBOARD_LL    :: 13
LLKHF_INJECTED    :: 0x00000010

VK_CAPITAL        :: 0x14

NIM_ADD           :: 0x00000000
NIM_MODIFY        :: 0x00000001
NIM_DELETE        :: 0x00000002
NIF_MESSAGE       :: 0x00000001
NIF_ICON          :: 0x00000002
NIF_TIP           :: 0x00000004

TPM_RIGHTBUTTON   :: 0x0002
MB_OK             :: 0x00000000
SW_HIDE           :: 0
ERROR_ALREADY_EXISTS :: 183
IMAGE_ICON       :: 1
LR_LOADFROMFILE  :: 0x00000010
LR_DEFAULTSIZE   :: 0x00000040
SM_CXSMICON      :: 49
SM_CYSMICON      :: 50

ID_TRAY_ENABLE    :: 1001
ID_TRAY_VERSION   :: 1002
ID_TRAY_EXIT      :: 1004
ID_TRAY_ICON      :: 1

HWND_MESSAGE_VALUE :: ~uintptr(2)
MAX_PATH          :: 260

HANDLE    :: rawptr
HWND      :: rawptr
HHOOK     :: rawptr
HINSTANCE :: rawptr
HMODULE   :: rawptr
HMENU     :: rawptr
HICON     :: rawptr
HBRUSH    :: rawptr
HCURSOR   :: rawptr
HKL       :: rawptr
WPARAM    :: uintptr
LPARAM    :: int
LRESULT   :: int
BOOL      :: b32

WNDPROC :: proc "stdcall" (hwnd: HWND, msg: u32, wparam: WPARAM, lparam: LPARAM) -> LRESULT
HOOKPROC :: proc "stdcall" (n_code: i32, wparam: WPARAM, lparam: LPARAM) -> LRESULT

POINT :: struct {
	x: i32,
	y: i32,
}

RECT :: struct {
	left:   i32,
	top:    i32,
	right:  i32,
	bottom: i32,
}

MSG :: struct {
	hwnd:    HWND,
	message: u32,
	wParam:  WPARAM,
	lParam:  LPARAM,
	time:    u32,
	pt:      POINT,
}

GUITHREADINFO :: struct {
	cbSize:        u32,
	flags:         u32,
	hwndActive:    HWND,
	hwndFocus:     HWND,
	hwndCapture:   HWND,
	hwndMenuOwner: HWND,
	hwndMoveSize:  HWND,
	hwndCaret:     HWND,
	rcCaret:       RECT,
}

WNDCLASSW :: struct {
	style:         u32,
	lpfnWndProc:  WNDPROC,
	cbClsExtra:   i32,
	cbWndExtra:   i32,
	hInstance:    HINSTANCE,
	hIcon:        HICON,
	hCursor:      HCURSOR,
	hbrBackground: HBRUSH,
	lpszMenuName:  [^]u16,
	lpszClassName: [^]u16,
}

NOTIFYICONDATAW :: struct {
	cbSize:           u32,
	hWnd:             HWND,
	uID:              u32,
	uFlags:           u32,
	uCallbackMessage: u32,
	hIcon:            HICON,
	szTip:            [128]u16,
	dwState:          u32,
	dwStateMask:      u32,
	szInfo:           [256]u16,
	uVersion:         u32,
	szInfoTitle:      [64]u16,
	dwInfoFlags:      u32,
	guidItem:         [16]u8,
	hBalloonIcon:     HICON,
}

KBDLLHOOKSTRUCT :: struct {
	vkCode:      u32,
	scanCode:    u32,
	flags:       u32,
	time:        u32,
	dwExtraInfo: uintptr,
}

foreign import user32 "system:user32.lib"
foreign user32 {
	SetWindowsHookExW   :: proc(id_hook: i32, hook_proc: HOOKPROC, instance: HINSTANCE, thread_id: u32) -> HHOOK ---
	UnhookWindowsHookEx :: proc(hook: HHOOK) -> BOOL ---
	CallNextHookEx      :: proc(hook: HHOOK, n_code: i32, wparam: WPARAM, lparam: LPARAM) -> LRESULT ---
	CreatePopupMenu     :: proc() -> HMENU ---
	AppendMenuW        :: proc(menu: HMENU, flags: u32, id: uintptr, text: [^]u16) -> BOOL ---
	SetForegroundWindow :: proc(hwnd: HWND) -> BOOL ---
	GetForegroundWindow :: proc() -> HWND ---
	GetWindowThreadProcessId :: proc(hwnd: HWND, process_id: ^u32) -> u32 ---
	GetGUIThreadInfo   :: proc(thread_id: u32, info: ^GUITHREADINFO) -> BOOL ---
	GetKeyboardLayout   :: proc(thread_id: u32) -> HKL ---
	GetKeyboardLayoutList :: proc(buffer_count: i32, list: [^]HKL) -> i32 ---
	ActivateKeyboardLayout :: proc(layout: HKL, flags: u32) -> HKL ---
	PostMessageW       :: proc(hwnd: HWND, msg: u32, wparam: WPARAM, lparam: LPARAM) -> BOOL ---
	SendMessageW       :: proc(hwnd: HWND, msg: u32, wparam: WPARAM, lparam: LPARAM) -> LRESULT ---
	TrackPopupMenu     :: proc(menu: HMENU, flags: u32, x: i32, y: i32, reserved: i32, hwnd: HWND, rect: rawptr) -> BOOL ---
	DestroyMenu        :: proc(menu: HMENU) -> BOOL ---
	GetCursorPos        :: proc(point: ^POINT) -> BOOL ---
	GetSystemMetrics    :: proc(index: i32) -> i32 ---
	MessageBoxW         :: proc(hwnd: HWND, text: [^]u16, caption: [^]u16, flags: u32) -> i32 ---
	PostQuitMessage    :: proc(exit_code: i32) ---
	RegisterClassW      :: proc(wnd_class: ^WNDCLASSW) -> u16 ---
	CreateWindowExW     :: proc(ex_style: u32, class_name: [^]u16, window_name: [^]u16, style: u32, x: i32, y: i32, width: i32, height: i32, parent: HWND, menu: HMENU, instance: HINSTANCE, param: rawptr) -> HWND ---
	DefWindowProcW      :: proc(hwnd: HWND, msg: u32, wparam: WPARAM, lparam: LPARAM) -> LRESULT ---
	GetMessageW         :: proc(msg: ^MSG, hwnd: HWND, filter_min: u32, filter_max: u32) -> BOOL ---
	TranslateMessage    :: proc(msg: ^MSG) -> BOOL ---
	DispatchMessageW    :: proc(msg: ^MSG) -> LRESULT ---
	DestroyWindow       :: proc(hwnd: HWND) -> BOOL ---
	LoadImageW          :: proc(instance: HINSTANCE, name: [^]u16, type_: u32, cx: i32, cy: i32, flags: u32) -> HANDLE ---
}

foreign import shell32 "system:shell32.lib"
foreign shell32 {
	Shell_NotifyIconW :: proc(message: u32, data: ^NOTIFYICONDATAW) -> BOOL ---
}

foreign import kernel32 "system:kernel32.lib"
foreign kernel32 {
	CreateMutexW       :: proc(attributes: rawptr, initial_owner: BOOL, name: [^]u16) -> HANDLE ---
	GetLastError       :: proc() -> u32 ---
	GetModuleHandleW   :: proc(module_name: [^]u16) -> HMODULE ---
	GetModuleFileNameW :: proc(module: HMODULE, filename: [^]u16, size: u32) -> u32 ---
	CloseHandle        :: proc(handle: HANDLE) -> BOOL ---
}

h_hook: HHOOK
main_window: HWND
tray_icon: HICON
enabled := true
debug_enabled := false
caps_processed := false

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
	if GetLastError() == ERROR_ALREADY_EXISTS {
		show_message("Another instance of switcherit is already running!", APP_NAME)
		return
	}
	defer CloseHandle(mutex)

	register_window_class()
	main_window = create_message_window()
	if main_window == nil {
		show_message("Could not create switcherit message window.", "switcherit Error")
		return
	}
	defer DestroyWindow(main_window)

	tray_icon = create_tray_icon()
	defer destroy_tray_icon()

	if !add_tray_icon(main_window) {
		show_message("Could not add switcherit tray icon.", "switcherit Error")
		return
	}
	defer remove_tray_icon(main_window)

	h_hook = SetWindowsHookExW(WH_KEYBOARD_LL, low_level_keyboard_proc, nil, 0)
	if h_hook == nil {
		show_message("Error calling SetWindowsHookExW.", "switcherit Error")
		return
	}
	defer UnhookWindowsHookEx(h_hook)

	log("started; enabled=%v", enabled)

	msg: MSG
	for GetMessageW(&msg, nil, 0, 0) != false {
		TranslateMessage(&msg)
		DispatchMessageW(&msg)
	}
}

register_window_class :: proc() {
	wc := WNDCLASSW {
		lpfnWndProc = window_proc,
		hInstance = GetModuleHandleW(nil),
		lpszClassName = wide_ptr("switcheritTrayWindow"),
	}
	RegisterClassW(&wc)
}

create_message_window :: proc() -> HWND {
	return CreateWindowExW(
		0,
		wide_ptr("switcheritTrayWindow"),
		wide_ptr(APP_NAME),
		0,
		0,
		0,
		0,
		0,
		cast(HWND)HWND_MESSAGE_VALUE,
		nil,
		GetModuleHandleW(nil),
		nil,
	)
}

window_proc :: proc "stdcall" (hwnd: HWND, msg: u32, wparam: WPARAM, lparam: LPARAM) -> LRESULT {
	context = runtime.default_context()

	switch msg {
	case WM_TRAY:
		if lparam == WM_RBUTTONUP || lparam == WM_CONTEXTMENU {
			show_tray_menu(hwnd)
		} else if lparam == WM_LBUTTONDBLCLK {
			enabled = !enabled
			update_tray_icon(hwnd)
		}
		return 0
	case WM_COMMAND:
		switch loword(wparam) {
		case ID_TRAY_ENABLE:
			enabled = !enabled
			update_tray_icon(hwnd)
		case ID_TRAY_VERSION:
			show_message(fmt.tprintf("%s %s", APP_NAME, APP_VERSION), APP_NAME)
		case ID_TRAY_EXIT:
			PostQuitMessage(0)
		}
		return 0
	case WM_DESTROY:
		PostQuitMessage(0)
		return 0
	}
	return DefWindowProcW(hwnd, msg, wparam, lparam)
}

show_tray_menu :: proc(hwnd: HWND) {
	menu := CreatePopupMenu()
	if menu == nil do return
	defer DestroyMenu(menu)

	enable_text := "Disable switcherit" if enabled else "Enable switcherit"
	append_menu(menu, ID_TRAY_ENABLE, enable_text)
	append_menu(menu, ID_TRAY_VERSION, "Version")
	append_menu(menu, ID_TRAY_EXIT, "Exit")

	pt: POINT
	GetCursorPos(&pt)
	SetForegroundWindow(hwnd)
	TrackPopupMenu(menu, TPM_RIGHTBUTTON, pt.x, pt.y, 0, hwnd, nil)
}

append_menu :: proc(menu: HMENU, id: uint, text: string) {
	AppendMenuW(menu, 0, uintptr(id), wide_ptr(text))
}

add_tray_icon :: proc(hwnd: HWND) -> bool {
	data := tray_data(hwnd)
	return Shell_NotifyIconW(NIM_ADD, &data) != false
}

update_tray_icon :: proc(hwnd: HWND) {
	data := tray_data(hwnd)
	Shell_NotifyIconW(NIM_MODIFY, &data)
}

remove_tray_icon :: proc(hwnd: HWND) {
	data := tray_data(hwnd)
	Shell_NotifyIconW(NIM_DELETE, &data)
}

tray_data :: proc(hwnd: HWND) -> NOTIFYICONDATAW {
	data: NOTIFYICONDATAW
	data.cbSize = size_of(NOTIFYICONDATAW)
	data.hWnd = hwnd
	data.uID = 1
	data.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP
	data.uCallbackMessage = WM_TRAY
	data.hIcon = tray_icon

	tip := "switcherit - enabled" if enabled else "switcherit - disabled"
	copy_wide_to_fixed(&data.szTip, tip)
	return data
}

create_tray_icon :: proc() -> HICON {
	width := GetSystemMetrics(SM_CXSMICON)
	height := GetSystemMetrics(SM_CYSMICON)

	icon := LoadImageW(GetModuleHandleW(nil), resource_ptr(ID_TRAY_ICON), IMAGE_ICON, width, height, 0)
	if icon != nil {
		return icon
	}

	icon = LoadImageW(nil, wide_ptr("assets\\switcherit-tray.ico"), IMAGE_ICON, width, height, LR_LOADFROMFILE)
	if icon != nil {
		return icon
	}

	and_mask: [32]u8
	xor_mask: [32]u8

	for i in 0..<len(xor_mask) {
		xor_mask[i] = 0xff
	}

	return cast(HICON)win.CreateIcon(nil, 16, 16, 1, 1, cast(^win.BYTE)&and_mask[0], cast(^win.BYTE)&xor_mask[0])
}

destroy_tray_icon :: proc() {
	if tray_icon != nil {
		win.DestroyIcon(cast(win.HICON)tray_icon)
		tray_icon = nil
	}
}

low_level_keyboard_proc :: proc "stdcall" (n_code: i32, wparam: WPARAM, lparam: LPARAM) -> LRESULT {
	context = runtime.default_context()

	key := cast(^KBDLLHOOKSTRUCT)uintptr(lparam)
	if n_code == HC_ACTION && key != nil {
		if (key.flags & LLKHF_INJECTED) != 0 {
			return CallNextHookEx(h_hook, n_code, wparam, lparam)
		}

		if key.vkCode == VK_CAPITAL {
			if wparam == WM_SYSKEYDOWN && !caps_processed {
				caps_processed = true
				enabled = !enabled
				log("Alt+CapsLock: enabled=%v", enabled)
				update_tray_icon(main_window)
				return 1
			}

			if wparam == WM_KEYDOWN && !caps_processed {
				caps_processed = true
			}

			if wparam == WM_KEYUP || wparam == WM_SYSKEYUP {
				caps_processed = false

				if enabled {
					log("CapsLock released: switching layout")
					switch_keyboard_layout()
				}
			}

			if !enabled {
				return CallNextHookEx(h_hook, n_code, wparam, lparam)
			}

			return 1
		}
	}

	return CallNextHookEx(h_hook, n_code, wparam, lparam)
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
		result := SendMessageW(target, WM_INPUTLANGCHANGEREQUEST, 0, cast(LPARAM)uintptr(next_layout))
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
		thread_id = GetWindowThreadProcessId(target, nil)
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

get_input_target_window :: proc() -> HWND {
	foreground := GetForegroundWindow()
	if foreground == nil do return nil

	thread_id := GetWindowThreadProcessId(foreground, nil)
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
	buffer: [MAX_PATH]u16
	n := GetModuleFileNameW(nil, &buffer[0], MAX_PATH)
	if n == 0 do return ""
	return wide_to_ascii(buffer[:n])
}

show_message :: proc(message: string, title: string) {
	MessageBoxW(nil, wide_ptr(message), wide_ptr(title), MB_OK)
}

log :: proc(format: string, args: ..any) {
	if !debug_enabled do return
	fmt.println(fmt.tprintf(format, ..args))
}

loword :: proc(value: uintptr) -> uint {
	return uint(value & 0xffff)
}

copy_wide_to_fixed :: proc(dst: ^[128]u16, text: string) {
	w := wide(text)
	count := min(len(w), len(dst^) - 1)
	for i in 0..<count {
		dst^[i] = w[i]
	}
	dst^[count] = 0
}

wide_ptr :: proc(s: string) -> [^]u16 {
	return raw_data(wide(s))
}

resource_ptr :: proc(id: uint) -> [^]u16 {
	return cast([^]u16)uintptr(id)
}

wide :: proc(s: string) -> []u16 {
	result := make([]u16, len(s) + 1)
	for i in 0..<len(s) {
		ch := s[i]
		result[i] = u16(ch) if ch < 0x80 else u16('?')
	}
	result[len(s)] = 0
	return result
}

wide_to_ascii :: proc(w: []u16) -> string {
	bytes := make([]u8, len(w))
	for i in 0..<len(w) {
		ch := w[i]
		bytes[i] = u8(ch) if ch < 0x80 else u8('?')
	}
	return string(bytes)
}
