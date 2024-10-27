package journey


/*
	This file serves as a documentation for the current and future support HID, GIP, XUSB device/s (game controllers).
	Refer to this file when parsing input report from device to host or sending output report from host to device.
	Input and output report layout maybe erroneous and are subject to change.
	Before changing journey_input change journey_hid_type if there is any layout change or supporting a new hid device.

*/


import "core:sys/windows"
import "core:c"

/////////////////// GUID ///////////////////
//GIP DeviceInterface (Xbox One protcol)
GIP_NAVIGATION_DEVICEINTERFACE_BYTE :: [8]windows.BYTE{0xA9, 0xF8, 0x2F, 0x21, 0x26, 0x3A, 0xCF, 0xB7}
GIP_GAMEPAD_DEVICEINTERFACE_BYTE :: [8]windows.BYTE{0xA5, 0xAB, 0xA3, 0x12, 0x7A, 0xF1, 0x97, 0xB5}
GIP_ARCADESTICK_DEVICEINTERFACE_BYTE :: [8]windows.BYTE{0xA3, 0x4A, 0xA6, 0xA6, 0x71, 0x1E, 0xC4, 0xB3}
GIP_FLIGHTSTICK_DEVICEINTERFACE_BYTE :: [8]windows.BYTE{0x96, 0x9C, 0x38, 0xDC, 0x55, 0xF4, 0x04, 0xD0}
GIP_RACINGWHEEL_DEVICEINTERFACE_BYTE :: [8]windows.BYTE{0x8D, 0xF9, 0x59, 0xE3, 0x98, 0xD7, 0x42, 0x0C}

gip_navigation_guid := windows.GUID{
	0xB8F31FE7,
	0x7386,
	0x40E9,
	GIP_NAVIGATION_DEVICEINTERFACE_BYTE,
}

gip_gamepad_guid := windows.GUID{
	0x082E402C,
	0x07DF,
	0x45E1,
	GIP_GAMEPAD_DEVICEINTERFACE_BYTE,
}

gip_arcadestick_guid := windows.GUID{
	0x332054CC,
	0xA34B,
	0x41D5,
	GIP_ARCADESTICK_DEVICEINTERFACE_BYTE,
}

gip_flightstick_guid := windows.GUID{
	0x03F1A011,
	0xEFE9,
	0x4CC1,
	GIP_FLIGHTSTICK_DEVICEINTERFACE_BYTE,
}

gip_racingwheel_guid := windows.GUID{
	0x646979CF,
	0x6B71,
	0x4E96,
	GIP_RACINGWHEEL_DEVICEINTERFACE_BYTE,
}

//XUSB DeviceInterface (Xbox 360 protcol)
XUSB_DEVICEINTERFACE_BYTE :: [8]windows.BYTE{0xB5, 0xF7, 0x8B, 0x84, 0xD5, 0x42, 0x60, 0xCB}

xusb_guid := windows.GUID{
	0xEC87F1E3,
	0xC12B,
	0x4100,
	XUSB_DEVICEINTERFACE_BYTE,
}

//USB DeviceInterface
USB_DEVICEINTERFACE_BYTE :: [8]windows.BYTE{0x90, 0x1F, 0x00, 0xC0, 0x4F, 0xB9, 0x51, 0xED}
usb_guid := windows.GUID{
	0x4D1E55B2,
	0xF16F,
	0x11CF,
	USB_DEVICEINTERFACE_BYTE,
}

//HID DeviceInterface

/////////////////// XUSB CONSTANT MAPPING ///////////////////

IOCTL_XUSB_GET_INFORMATION :: 0x8000a010
IOCTL_XUSB_GET_CAPABILITIES :: 0x8000E004
IOCTL_XUSB_GET_LED_STATE :: 0x8000E008
IOCTL_XUSB_GET_STATE :: 0x8000E00C
IOCTL_XUSB_SET_STATE :: 0x8000A010
IOCTL_XUSB_WAIT_GUIDE_BUTTON :: 0x8000E014
IOCTL_XUSB_GET_BATTERY_INFORMATION :: 0x8000E018
IOCTL_XUSB_POWER_DOWN :: 0x8000A01C
IOCTL_XUSB_GET_AUDIO_DEVICE_INFOMATION :: 0x8000E020
IOCTL_XUSB_WAIT_FOR_INPUT :: 0x8000E3AC
IOCTL_XUSB_GET_INFORMATION_EX :: 0x8000E3FC
IOCTL_XUSB_GET_XINPUT_MANAGEMENT_DRIVER :: 0x80006380
IOCTL_XUSB_WAIT_FOR_SYSTEM_BUTTONS :: 0x8000E384

XUSB_SET_STATE_LED :: 0x01
XUSB_SET_STATE_VIBRATE :: 0x02 

XUSB_BATTERY_TYPE_GAMEPAD :: 0x00

XUSB_META_XUSBVERSION :: 0xFF
XUSB_META_STATUS :: 0xF00

XUSB_BATTERY_TYPE_DISCONNECTED :: 0x0
XUSB_BATTERY_TYPE_WIRED :: 0x01
XUSB_BATTERY_TYPE_ALKALINE :: 0x02
XUSB_BATTERY_TYPE_NIMH :: 0x03
XUSB_BATERY_TYPE_UNKOWN :: 0xFF

XUSB_BATTERY_LEVEL_EMPTY :: 0x00
XUSB_BATTERY_LEVEL_LOW :: 0x01
XUSB_BATTERY_LEVEL_MEDIUM :: 0x02
XUSB_BATTERY_LEVEL_FULL :: 0x03

XUSB_TYPE_UNKOWN :: 0x00
XUSB_TYPE_GAMEPAD :: 0x01

//Controller button mask
XUSB_DPAD_UP :: 0x0001
XUSB_DPAD_DOWN :: 0x0002
XUSB_DPAD_LEFT :: 0x0004
XUSB_DPAD_RIGHT :: 0x0008

XUSB_START :: 0x0010
XUSB_BACK :: 0x0020

XUSB_LEFT_THUMB :: 0x0040
XUSB_RIGHT_THUMB :: 0x0080
XUSB_LEFT_SHOULDER :: 0x0100
XUSB_RIGHT_SHOULDER :: 0x0200

XUSB_A :: 0x1000
XUSB_B :: 0x2000
XUSB_X :: 0x4000
XUSB_Y :: 0x8000


///////////////////XUSB Report Layout///////////////////
XUSBState :: struct #packed{
	//refer to the mask above.
	buttons : u16,

	l2_axis : u8,
	r2_axis : u8,

	//Can map to -32768 to 32767
	l_joystick_x : i16,
	l_joystick_y : i16,
	r_joystick_x : i16,
	r_joystick_y : i16,
}


XUSBStateEx :: struct #packed{
	meta : u32,
	input_id : u8,

	//incremented only if there was change from last poll
	packet_number : u32,

	padding : u16,
	
	common : XUSBState,

	padding_0 : [6]u8,
}

XUSBInput :: struct #packed{
	//usually keep at 0x101
	xusb_version : u16,
	device_index : u8,

}

XUSBBatteryType :: enum u8{
	BatteryTypeDisconnect = 0x00,
	BatteryTypeWired = 0x01,
	BatteryTypeAlkaline = 0x02,
	BatteryTypeNimh = 0x03,
	BatteryTypeUnknown = 0xFF,
}

XUSBBatteryLevel :: enum u8{
	BatteryLevelUnknown = 0x00,
	BatteryLevelLow = 0x01,
	BatteryLevelMedium = 0x02,
	BatteryLevelFull = 0x03,
}

XUSBBatteryDeviceType :: enum u8{
	BatteryDeviceGamepad = 0x00,
	BatteryDeviceHeadset = 0x01,
}

XUSBBatteryInfoInput :: struct #packed{
	//usually keep at 0x102
	xusb_version : u16,
	device_index : u8,
	device_type : XUSBBatteryDeviceType,
}

XUSBBatteryInfoOutput ::struct #packed{
	v : u16,
	battery_type : XUSBBatteryType,
	battery_level : XUSBBatteryLevel,
}

XUSBOutput :: struct #packed{
	device_index : u8,
	led_state : u8,
	left_strength : u8,
	right_strength : u8,
	flag : u8, //I wonder if we can set both flag at the same time.
}


/////////////////// GIP CONSTANT MAPPING ///////////////////

IOCTL_GIP_ADD_REENUMERATE_CALLER_CONTEXT :: 0x40001CD0

GIP_DEVICE_ARRIVAL :: 0x02
GIP_DEVICE_STATUS :: 0x03
GIP_DEVICE_DESCRIPTOR :: 0x04
GIP_SET_DEVICE_STATE :: 0x09
GIP_DEVICE_INPUT_REPORT :: 0x20
GIP_SYSTEM_FOCUS_CHANGE :: 0xE0

GIP_SYNC :: 0x0001
GIP_MENU :: 0x0004
GIP_VIEW :: 0x0008

GIP_A :: 0x0010
GIP_B :: 0x0020
GIP_X :: 0x0040
GIP_Y :: 0x0080

GIP_DPAD_UP :: 0x0100
GIP_DPAD_DOWN :: 0x0200
GIP_DPAD_LEFT :: 0x0400
GIP_DPAD_RIGHT :: 0x0800

GIP_LEFT_SHOULDER :: 0x1000
GIP_RIGHT_SHOULDER :: 0x2000
GIP_LEFT_THUMB :: 0x4000
GIP_RIGHT_THUMB :: 0x8000



///////////////////GIP Report Layout///////////////////

gip_path := [12]u16{0x5C, 0x5C, 0x2E, 0x5C, 0x58, 0x62, 0x6F, 0x78, 0x47, 0x49, 0x50, 0x0}


GipHeader :: struct #packed{
	device_id : u64,
	command_id : u8, //command id that indicate the type of message being sent
	param : u8, //flag 4 bit, client 4 bit

	sequence : u8,

	unknown_0 : u8,
	length : u32,
	unkown_1 : u32,
}

//Use in param 4 lo bits
GipHeaderFlag :: enum u8{
	None = 0x00,
	Internal = 0x20,
}

GipFirmwareVersion :: struct #packed{
	major : u16,
	minor : u16,
	build : u16,
	revision : u16,
}

//0x02
GipArrival :: struct #packed{
	header : GipHeader,
	device_id : u64,
	vendor_id : u16,
	product_id : u16,
	firm : GipFirmwareVersion,
	unknown : [13]u8,
}

GipBatteryType :: enum u8{
	Wired = 0x00,
	Standard = 0x01,
	ChargeKit = 0x02,
}


GipBatteryLevel :: enum u8{
	Low = 0x00,
	Medium = 0x01,
	High = 0x02,
	Full = 0x03,
}

//0x03
GipStatus :: struct #packed{
	header : GipHeader,
	battery : u8, //battery_level 2, battery_type 2, unknown 3, connected 1
	unknown : [3]u8,
}

//0x04
GipDescriptorHeader :: struct #packed{
	vendor_id : u16,
	product_id : u16,

	unknown : [14]u8,
	length : u16,

	offset_external_commands : u16,
	offset_firmware_versions : u16,
	offset_audio_formats : u16,
	offset_input_commands : u16,
	offset_output_commands : u16,
	offet_class_names : u16,
	offset_interface_guids : u16,
	offset_hid_descriptor : u16,
}

GipDescriptor :: struct #packed{
	header : GipHeader,
	gip_descriptor_header : GipDescriptorHeader,
	buffer : []u8, //length == descriptor_header.length - 32
}


GipExternalCommandFlag :: enum u8{
	Unknown = 0x04,
	Output = 0x08,
	Input = 0x10,
} 

GipExternalCommand :: struct #packed{
	unknown1 : u16,
	command : u8,
	max_length : u16,
	unknown2 : u16,
	flags : u8,
	unknown3 : [15]u8,
}

GipAudioFormat :: struct #packed{
	unknown : [2]u8,
}

GipClassName :: struct #packed{
	length : u16,
	buffer : []u8,
}


GipForceFeedbackFlag :: enum u8{
	RightMotor = 0x01,
	LeftMotor = 0x02,
	RightTrigger = 0x04,
	LeftTrigger = 0x08,
}

//For Gip Gamepad
GipForceFeedback :: struct #packed{
	header : GipHeader,
	unknown0 : u8,// we will set this to 0x03
	flags : u8,
	left_trigger : u8,
	right_trigger : u8,
	left_motor : u8,
	right_motor : u8,
	duration : u8,
	delay : u8,
	repeat : u8,
}

GipGamepadInput :: struct #packed{
	header : GipHeader,
	buttons : u16,
	left_trigger : u16, // 0x00 to 0x3FF
	right_trigger : u16, // 0x00 to 0x3FF
	left_stick_x : u16,
	left_stick_y : u16,
	right_stick_x : u16,
	right_stick_y : u16,
}

GipFocusStatus :: enum u8{
	Unfocused = 0x00,
	Focused = 0x01,
}

GipFocusChange :: struct #packed{
	gip_header : GipHeader,
	status : u8,
	unknown : [7]u8,

}

///////////////////DualSense CRC HASH///////////////////

PS_CRC_OFFSET :: 0x4A

ps_input_crc32_seed :u8= 0xA1
ps_output_crc32_seed :u8= 0xA2
ps_feature_crc32_seed :u8= 0xA3

///////////////////DualSense Flag///////////////////

//First flag in the first byte of the output report. (Multi)
DualSenseFlag0 :: enum u8{
	EnableRumbleEmulation = 0x01,
	UseRumbleNotHaptics = 0x02,
	AllowRightTriggerForceFeedback = 0x04,
	AllowLeftTriggerForceFeedback = 0x08,
	AllowHeadphoneVolume = 0x10,
	AllowSpeakerVolume = 0x20,
	AllowMicVolume = 0x40,
	AllowAudioControlFlag = 0x80,
}


//Second flag in the second byte of the output report. (Multi)
DualSenseFlag1 :: enum u8{
	AllowMuteLight = 0x01,
	AllowAudioMute = 0x02,
	AllowLedColor = 0x04,
	ResetLights = 0x08,
	AllowPlayerIndicator = 0x10,
	AllowHapticLowPassFilter = 0x20,
	AllowMotorPowerLevel = 0x40,
	AllowAudioControl2Flag = 0x80,
}

//MuteControl in the 10 byte of the output report. (Multi)
MuteControlFlag :: enum u8{
	TouchPowerSave = 0x01,
	MotionPowerSave = 0x02,
	HapticPowerSave = 0x04,
	AudioPowerSave = 0x08,
	MicMute = 0x10,
	SpeakerMute = 0x20,
	HeadphoneMute = 0x40,
	HapticMute = 0x80,
}


//Advance Flag in the 39 byte of the output report. (Multi)
AdvancedFlag :: enum u8{
	AllowLightBrightnessChange = 0x01,
	AllowColorLightFadeAnimation = 0x02,
	EnableImprovedRumbleEmulation = 0x04,
}


//for the flag refer above eg. (AdvancedFlag.AllowLightBrightnessChage | AdvancedFlag.EnableImprovedRumbleEmulation)
DualSenseConfigFlag :: struct{
	dualsense_flag_1 : u8,
	dualsense_flag_2 : u8,
	mute_control_flag : u8,
	advance_flag : u8,
	

}

///////////////////HID CONSTANT MAPPING/////////////////////

HID_VENDOR_MICROSOFT :: 0x45E //0100 0101 1110
HID_VENDOR_SONY :: 0x54C      //0101 0100 1100


DUALSENSE_BT_INPUT_REPORT_LENGTH :: 0x4E
DUALSENSE_USB_INPUT_REPORT_LENGTH :: 0x40
DUALSENSE_BT_OUTPUT_REPORT_LENGTH :: 0x4E
DUALSENSE_USB_OUTPUT_REPORT_LENGTH :: 0x3F
DUALSENSE_FIRMWARE_FEATURE_REPORT_LENGTH :: 0x40
///////////////////Xbox One///////////////////
HID_MICROSOFT_XBOX_ONE :: 0x2D1

///////////////////Xbox One S///////////////////
//Windows mode, non android mode
HID_MICROSOFT_XBOX_ONE_S_BLUETOOTH_0 :: 0x2E0
//Linux mode, android mode
HID_MICROSOFT_XBOX_ONE_S_BLUETOOTH_1 :: 0x2FD

HID_MICROSOFT_XBOX_ONE_S_USB :: 0x2EA

///////////////////Xbox Elite 1,2///////////////////
HID_MICROSOFT_XBOX_ONE_ELITE_USB :: 0x2E3
HID_MICROSOFT_XBOX_ONE_ELITE_BLUETOOTH :: 0x2FF 
HID_MICROSOFT_XBOX_ONE_ELITE_2_USB :: 0xB00
HID_MICROSOFT_XBOX_ONE_ELITE_2_BLUETOOTH :: 0xB05
HID_MICROSOFT_XBOX_ONE_ELITE_2_BLE :: 0x0B22

///////////////////Xbox One S|X///////////////////
HID_MICROSOFT_XBOX_ONE_S_X_USB :: 0xB12
HID_MICROSOFT_XBOX_ONE_S_X_BLUETOOTH :: 0xB13

///////////////////Xbox One BLE///////////////////
HID_MICRSOFT_XBOX_BLE_BLUETOOTH :: 0xB20

///////////////////Sony EDGE USB/BLUETOOTH///////////////////
HID_SONY_DUALSENSE_EDGE :: 0xDF2

///////////////////Sony SENSE USB/BLUETOOTH///////////////////
HID_SONY_DUALSENSE :: 0xCE6   

///////////////////////////////////HID Input Report Layout///////////////////////////////////

DualSenseTriggerEffect :: enum u8{
	//No Haptic Trigger Effect or Custom
	None = 0,
	Feedback = 1,
	Weapon = 2,
	Vibration = 3,
	Bow = 4,
	Gallope = 5,
	Machine = 6,
}

DualSenseConnection :: enum u8{
	USB = 0x1,
	BLUETOOTH = 0x2,
}

DualSenseMuteLight :: enum u8{
	Off = 0,
	On,
	Breathing,
	DoNothing,
	
	NoAction4,
	NoAction5,
	NoAction6,
	NoAction7 = 7,

}


DualSenseLightFadeAnimation :: enum u8{
	Nothing = 0,
	FadeIn, //black to blue
	FadeOut, //blue to black
}

DualSenseLightBrightness :: enum u8{
	Bright = 0,
	Mid,
	Dim,
	NoAction3,
	NoAction4,
	NoAction5,
	NoAction6,
	NoAction7,
}


IDualSense_Touch_Data :: struct #packed{
	touch_counter : u8, //33 . when pressed the last bit from a byte is zeroe d and increment other wise the last bit in a byte is set to 1 if released. 

	touch_1 : u8, //34 single touch_x
	touch_2 : u8, //35 4 low bit are for the touch x high 4 bit are for touch y
	touch_3 : u8, //36 single touch_y 	
}


//Sony DualSense Raw USB Input Mapping.
IUDualSense ::  struct #packed{
	//report_id : u8, //0x1

	l_joystick_x : u8,
	l_joystick_y : u8,
	
	r_joystick_x : u8,
	r_joystick_y : u8,

	l2_axis : u8,
	r2_axis : u8,
	
	//Counter for input report sent. Will wrap back after the counter reaches max value of u8
	input_report_sent : u8,
	
	//Dpad 4 bits. Shares other 4 bits with button.
	//Square is bit 5, X is bit 6, O is bit 7, and Triangle is bit (1 mean pressed 0 mean not pressed)
	button_0 : u8,

	//The 8 bit order goes by the following;
	//l1, r1, l2, r2, select, start, l3 down, r3 down
	button_1 : u8,

	//The 3 bit are used for button, which are the following;
	//The 5 bit following 5 bits are dual sense edge parameters. (Not Tested)
	//Home, Pad, Mic
	button_2 : u8,

	unused_0 : u8, //11 unused

	unused_1 : u8, //12 count till 255 fast
	unused_2 : u8, //13 counter slower
	unused_3 : u8, //14  67 constant?
	unused_4 : u8, //15 152 constant?

	gyroscope_x : i16, //16, 17
	gyroscope_y : i16, //18, 19
	gyroscope_z : i16, //20, 21
	
	velocity_x : i16, //22, 23
	velocity_y : i16, //24, 25
	velocity_z : i16, //26, 27
	
	// (sensor timestep) 
	sensor_time_step_0 : u8,//28
	sensor_time_step_1 : u8,//29
	sensor_time_step_2 : u8,//30
	sensor_time_step_3 : u8,//31

	temperature : u8,

	single_touch : IDualSense_Touch_Data, //33 - 36
	dual_touch : IDualSense_Touch_Data, //37 - 40
	//touch_timestamp : u8, //41

	haptic_r2_trigger : u8, //42 low 4 bits for the stop (0 to 9), high 4 bits for status (0, 64)
	haptic_l2_trigger : u8, //43 low 4 bits for the stop (0 to 9), high 4 bits for status (0, 64)

	unused_6 : u8, // 44
	unused_7 : u8, // 45
	unused_8 : u8, // 46
	unused_9 : u8, // 47

	haptic_trigger_effect : u8, //48 low 4 bits are r2 trigger effect, the high 4 bits are the l2 trigger effect.

	unused_10 : u8, //49
	unused_11 : u8, //50
	unused_12 : u8, //51
	unused_13 : u8, //52

	battery : u8, //53 lower 4 bit for battery percentage (0 to 10) high 4 bit is enum

	plugged_data : u8, //54, single bit indicating (mute on, plugged headphone, plugged mic, etc..) I am skipping, since headset are plugged through the pc and not the controller.

	unused_14 : [10]u8, //64
}

//Note not entirely sure if the layout is correct here.
//Sony DualSense Raw Bluetooth Input Mapping
IBDualSense :: struct #packed{
	report_id : u8, //0x31
	//1 bit is HAS_HID, 2 bit is HAS_MIC,3 and 4 bit are Unkown, 5,6,7,8 bit are sequence number 
	seq_tag : u8,
	common : IUDualSense,
	padding : [9]u8,
	crc : u32,
}


//Sony DualSense Raw Bluetooth Simple Input Mapping.
ISimpleBDualSense :: struct #packed{
	report_id : u8, // 0x01

    l_joystick_x : u8,
    l_joystick_y : u8,

    r_joystick_x : u8,
    r_joystick_y : u8,
	
	//DPad 4 bits. Shares other 4 bits with button
	//Square is the 5 bit, X is the 6 bit, O is the 7 bit, and Triangle is bit 8
	button_0 : u8,

	//The 8 bit order goes by the following;
	//l1, r1, l2, r2, select, start, l3 down, r3 down 
	button_1 : u8,

	//the 2 bits are for button (home is the first bit and the touch pad button is the second bit) the reset of the 6 bits are padding.
	button_2 : u8,

	// Doesn't give binary values (0, 1) as button but 0 to 255 depending on how much pressure your giving these button.
	l2_axis : u8,
	r2_axis : u8,
}

//GIP
InputXboxOne :: struct #packed{
	buttons : u16,
	l_trigger : u16,
	r_trigger : u16,
	l_stick_x : i16,
	l_stick_y : i16,
	r_stick_x : i16,
	r_stick_y : i16,
}

//HID
IBXboxOneSX :: struct #packed{
	report_id : u8,
	
	l_joystick_x : u16,
	l_joystick_y : u16,

	r_joystick_x : u16,
	r_joystick_y : u16,

	//Seem like the trigger are shared -.-' unless I use Xinput, but I don't want to use Xinput.
	//Doesn't return binary result of the trigger, but rather the pressure sensitivity applied on the trigger. The first 10 bits are valid result, but the rest of the 6 bits are padding and invalid.
	//l_trigger : u16,
	//r_trigger : u16,
	shared_trigger : u16,//11

	//A,B,X,Y,L1,R1,Select,Start,L3,R3, Xbox, Download
	buttons : u16,//13

	hat_switch : u8,

	unused_0 : [2]u8,
}

///////////////////////////////////HID Output Report Layout///////////////////////////////////

TriggerEffectType :: enum u32{
	Off = 0x05,
	Feedback = 0x21,
	Weapon = 0x25,
	Vibration = 0x26,

	Bow = 0x22,
	Galloping = 0x23,
	Machine = 0x27,	
}

OUDualSense :: struct #packed{
	//report_id : u8, //0x2

	//Enable rumble emulation, Use rumble not haptic, Allow R3 adaptive trigger, Allow L3 adaptive trigger
	//Allow Headphone volume, Allow speaker volume, Allow mic volume, Allow audio control
	flag_0 : u8,

	//Allow mute light, Allow audio mute, Allow led color, reset lights
	//Allow player indicators, allow haptic low pass filter, allow motor power level, allow audio control_2
	flag_1 : u8,

	r2_haptic_feedback : u8,
	l2_haptic_feedback : u8,

	volume_headphones : u8, //max is 0x7F
	volume_speaker : u8, // range 0x3D - 0x64
	volume_mic : u8,

	//Audio control
	//we will skip this completely. 
	audio_ctrl_0 : u8,

	mute_light_mode : DualSenseMuteLight,
	
	//Mute Control
	
	//Touch power save, Motion power save, Haptic power save, Audio power save,
	//Mic mute, Speaker mute, Headphone mute, Haptic mute, 
	power_save_control : u8,

	r3_adaptive_trigger_param : [11]u8,
	l3_adpative_trigger_param : [11]u8,
	
	host_timestamp : u32,

	motor_power_reduction : u8,

	//Audio control 2
	//we will skip this completely
	audio_ctrl_1 : u8,

	//Allow light brightness change, Allow Color light fade animation, Enable improved rumble emulation
	//rest of the 5 bits a are unused 
	advanced_flag : u8,

	//only uses one bit
	haptic_low_pass_filter : u8,

	unused : u8,

	light_fade_animation : DualSenseLightFadeAnimation,
	light_brightness : DualSenseLightBrightness,

	player_light : u8,

	led_red : u8,
	led_green : u8,
	led_blue : u8,
}


OBDualSense :: struct #packed{
	report_id : u8, //0x31
	seq_tag : u8,
	tag : u8,
	
	common : OUDualSense,
	padding : [24]u8,
	
	crc32 : u32,

}


OutputMotorFlag :: enum u8{
	RightMotor = 0x01,
	LeftMotor = 0x02,
	RightMotorTrigger = 0x04,
	LeftMotorTrigger = 0x08,
}

//BT & USB GIP Protocol without header
OutputXboxOne :: struct #packed{
	unknown : u8, //probably report id
	motor_flags : u8,
	left_trigger : u8,
	right_trigger : u8,
	left_motor : u8,
	right_motor : u8,
	duration : u8,
	delay : u8,
	repeat : u8,
}

///////////////////////////////////HID Feature Report Layout///////////////////////////////////

FDualSense :: struct #packed{
	report_id : u8,
	build_date : [11]u8,
	build_time : [8]u8,
	fwType : u16,
	swSeries : u16,
	hardware_info : u32,
	
	firm_version : u32,
	device_info : [12]u8,

	update_version : u16,
	update_img_info : u8,
	
	update_unkown : u8,

	fw_version_1 : u32,
	fw_version_2 : u32,
	fw_version_3 : u32,
	
}