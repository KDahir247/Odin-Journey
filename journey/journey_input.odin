//+build windows
package journey

//test
import "core:os"

import "core:fmt"
import "core:thread"
import "core:sys/windows"
import "core:mem/virtual"
import "core:math"
import "core:simd/x86"

import "base:runtime"
import "base:intrinsics"

import "vendor:zlib"

//Support for Audio haptic feedback isn't implemented yet. Speaker, Mic, Headphone isn't implement yet as well This will most likely be implemented later to support Audio haptic feedback.

// When Optimizing use Zen2 family as target CPU
// refer to uops table, agner fog, wikichip, amd zen2 manual, & disassembler when optimizing this.

// refer to USB documentation for HID specification

//TODO: Khal we now need to create the syncronization between the game thread and the input thread.

//We will read input from the input thread to the game thread and do operation on the game thread that will take around 40 cycle before we process the input on the game thread
//Input thread -> Game thread (Device -> Host)

//We will read the output from the game thread to the input thread and do operation on the input thread that will take around 40 cycle before we process the output on the input thread
//Game thread -> Input thread (Host -> Device)

DPAD_UP :: 0x01
DPAD_UP_RIGHT :: 0x03
DPAD_RIGHT :: 0x02
DPAD_DOWN_RIGHT :: 0x06
DPAD_DOWN :: 0x04
DPAD_DOWN_LEFT :: 0x0C
DPAD_LEFT :: 0x08
DPAD_UP_LEFT :: 0x09

ACTION_A :: 0x10
ACTION_B :: 0x20
ACTION_X :: 0x40
ACTION_Y :: 0x80

ACTION_SELECT :: 0x100
ACTION_OPTION :: 0x200

L1_TRIGGER :: 0x400
R1_TRIGGER :: 0x800

ACTION_L3 :: 0x1000
ACTION_R3 :: 0x2000

CONTROLLER_RING_BUFFER_CAPACITY :: 64

RIDI_PREPARSEDATA :: 0x20000005
RIDI_DEVICENAME :: 0x20000007
RIDI_DEVICEINFO :: 0x2000000b

//TODO:khal bad naming Xbox doesn't use HID but GIP Protocol
CHIDProperty :: struct{
	handle : windows.HANDLE, //Do we need this

	vendor_id : u32,
	product_id : u32, //Do we need this

	input_byte_len : u32,
	output_byte_len : u32,

	firm_version : u32, //Do we need this
	padding : u32,
}

GameController :: struct #align(16){
	left_analog_x : f32,
	left_analog_y : f32,
	right_analog_x : f32,
	right_analog_y : f32,

	left_trigger : u32,
	right_trigger : u32,

	buttons : u32,
	battery_info : u32,
}


Button :: struct{
	flag : u32,
	transition : u32,
	delta_ms : i32,
	delta_threshold_ms : i32,
}

GameInput :: struct{
	/* Controller Action*/
	controller : GameController,

	/* Keyboard Action */
	action_buttons : [4]Button,

	/* Mouse Action */
	mouse_buttons : Button,

	/* Text Input */
}

ControllerDescriptor :: struct{
	radial_deadzone : f32,
	axial_deadzone : f32,
	anti_radial_deadzone : f32,
	outer_deadzone_input : f32,
	outer_deadzone_output : f32,
	response_curve : f32,
	trigger_deadzone : f32,
}

TriggerDescriptor :: struct{
	params_0 : [4]u32,
	params_1 : [4]u32,
	params_2 : [4]u32,
}

NEXTRAWINPUTBLOCK :: proc(x : windows.PRAWINPUT) -> windows.PRAWINPUT{
	return windows.PRAWINPUT(RAWINPUT_ALIGN(rawptr(uintptr(x) + uintptr(x.header.dwSize))))
}

RAWINPUT_ALIGN :: proc(x : rawptr) -> rawptr{
	return rawptr((uintptr(x) + size_of(windows.QWORD) - 1) & ~uintptr(size_of(windows.QWORD) - 1))
}

ControllerIsPressed :: #force_inline proc(game_controller : ^GameController, $mask : u32) -> b32{
	return (game_controller_buttons & mask) == mask
}

/////////////////////////////////////////DualSense/////////////////////////////////////////

LEFT_TRIGGER_INDEX : u8 : 0x0000_0015
RIGHT_TRIGGER_INDEX : u8 : 0x0000_000A

DualSenseTriggerOff :: #force_inline proc "contextless" (ffb_destination : []u8, $trigger_index : u8) #no_bounds_check{

	intrinsics.mem_zero(raw_data(ffb_destination[trigger:]), 11)
	ffb_destination[trigger_index] = 0x05
}

//DualSenseTriggerFeedback will not do any sanity checks.
//Parameters:
//trigger_desc.params_0.x is strength (1 <= value <= 7)
//trigger_desc.params_0.y is position (0 <= value <= 9)
//trigger_desc.params_0.z is frequency_hz (0 <= value)
DualSenseTriggerFeedback :: proc "contextless" (trigger_desc : ^TriggerDescriptor, ffb_destination : []u8, $trigger_index : u8) #no_bounds_check{
	FORCE_ZONE_FACTOR : u32 : 0x0924_9248
	FORCE_ZONE_MASK_FACTOR : u32 : 0x0000_00003

	effect_bit := 0x26

	force_zone_unmasked := trigger_desc.params_0.x * FORCE_ZONE_FACTOR

	force_mask : u32 = 0xFFFF_FFFFF << (trigger_desc.params_0.y * FORCE_ZONE_MASK_FACTOR)
	active_mask : u32 = 0x3FF << trigger_desc.params_0.y

	force_zones := force_zone_unmasked & force_mask
	active_zones := 0x3FF & active_mask

	//If frequency hasn't been set then we go to feedback rather then vibration.
	if trigger_desc.params_0.z <= 0{
		effect_bit = 0x21
	}

	ffb_destination[trigger_index] = u8(effect_bit)
	ffb_destination[trigger_index + 0x01] = u8((active_zones / 0x0000_0001) & 0xFF)
	ffb_destination[trigger_index + 0x02] = u8((active_zones / 0x0000_0100) & 0xFF)
	ffb_destination[trigger_index + 0x03] = u8((force_zones  / 0x0000_0001) & 0xFF)
	ffb_destination[trigger_index + 0x04] = u8((force_zones  / 0x0000_0100) & 0xFF)
	ffb_destination[trigger_index + 0x05] = u8((force_zones  / 0x0001_0000) & 0xFF)
	ffb_destination[trigger_index + 0x06] = u8((force_zones  / 0x0100_0000) & 0xFF)
	ffb_destination[trigger_index + 0x07] = 0x00
	ffb_destination[trigger_index + 0x08] = 0x00
	ffb_destination[trigger_index + 0x09] = u8(trigger_desc.params_0.z)
	ffb_destination[trigger_index + 0x0A] = 0x00
}

//DualSenseTriggerMultiPosFeedback will not do any sanity checks.
//Parameters:
//trigger_desc.params_0.xyzw = first of the four strength (0 < value <= 7)
//trigger_desc.params_1.xyzw = second of the four strength (0 < value <= 7)
//trigger_desc_params_2.xy = third of the four strength. Only two elements are used (0 < value <= 7)
//uses 10 parameters which values range from 0 to 7, all 10 parameters can not be 0
DualSenseTriggerMultiPosFeedback :: proc "contextless" (trigger_desc : ^TriggerDescriptor, ffb_destination : []u8, $trigger_index : u8) #no_bounds_check{
	FORCE_ZONES_SHIFT_0 :: [4]u32{0x0000_0001, 0x0000_0008, 0x0000_0040, 0x0000_0200}
	FORCE_ZONES_SHIFT_1 :: [4]u32{0x0000_1000, 0x0000_8000, 0x0004_0000, 0x0020_0000}
	FORCE_ZONES_SHIFT_2 :: [4]u32{0x0100_0000, 0x0800_0000, 0x0000_0000, 0x0000_0000}

	force_zone_elements := (trigger_desc.params_0 * FORCE_ZONES_SHIFT_0) | (trigger_desc.params_1 * FORCE_ZONES_SHIFT_1) | (trigger_desc.params_2 * FORCE_ZONES_SHIFT_2)

	force_zone := (force_zone_elements.x | force_zone_elements.y) | (force_zone_elements.z | force_zone_elements.w)

	ffb_destination[trigger_index] = 0x21
	ffb_destination[trigger_index + 0x01] = 0xFF
	ffb_destination[trigger_index + 0x02] = 0x03
	ffb_destination[trigger_index + 0x03] = u8((force_zone / 0x0000_0001) & 0xFF)
	ffb_destination[trigger_index + 0x04] = u8((force_zone / 0x0000_0100) & 0xFF)
	ffb_destination[trigger_index + 0x05] = u8((force_zone / 0x0001_0000) & 0xFF)
	ffb_destination[trigger_index + 0x06] = u8((force_zone / 0x0100_0000) & 0xFF)
	ffb_destination[trigger_index + 0x07] = 0x00
	ffb_destination[trigger_index + 0x08] = 0x00
	ffb_destination[trigger_index + 0x09] = 0x00
	ffb_destination[trigger_index + 0x0A] = 0x00
}


//DualSenseTriggerWeapon will not do any sanity checks.
//Parameters:
//trigger_desc.params_0.x = start position (2 <= value <= 7)
//trigger_desc.params_0.y = end position (start position + 1 <= value <= 8)
//trigger_desc.params_0.z = strength (0 <= value <= 7)
DualSenseTriggerWeapon :: proc "contextless" (trigger_desc : ^TriggerDescriptor, ffb_destination : []u8, $trigger_index : u8) #no_bounds_check{

	start_stop_zone :u32 = (1 << trigger_desc.params_0.x) | (1 << trigger_desc.params_0.y)

	ffb_destination[trigger_index] = 0x25
	ffb_destination[trigger_index + 0x01] = u8((start_stop_zone / 0x0000_0001) & 0xFF)
	ffb_destination[trigger_index + 0x02] = u8((start_stop_zone / 0x0000_0100) & 0xFF)
	ffb_destination[trigger_index + 0x03] = u8(trigger_desc.params_0.z)
	ffb_destination[trigger_index + 0x04] = 0x00
	ffb_destination[trigger_index + 0x05] = 0x00
	ffb_destination[trigger_index + 0x06] = 0x00
	ffb_destination[trigger_index + 0x07] = 0x00
	ffb_destination[trigger_index + 0x08] = 0x00
	ffb_destination[trigger_index + 0x09] = 0x00
	ffb_destination[trigger_index + 0x0A] = 0x00
}


//DualSenseTriggerBow will not do any sanity checks
//Parameters:
//trigger_desc.params_0.x = start position (0 <= value <= 7)
//trigger_desc.params_0.y = end position (start position + 1 <= value <= 8)
//trigger_desc.params_0.z = strength (0 <= value <= 8)
//trigger_desc.params_0.w = snap force (0 <= value <= 8)
DualSenseTriggerBow :: proc "contextless" (trigger_desc : ^TriggerDescriptor, ffb_destination : []u8, $trigger_index : u8) #no_bounds_check{

	start_stop_zone : u32 = (1 << trigger_desc.params_0.x) | (1 << trigger_desc.params_0.y)
	force_zone := (trigger_desc.params_0.z * 0x0000_0001) | (trigger_desc.params_0.w * 0x0000_0008)

	ffb_destination[trigger_index] = 0x22
	ffb_destination[trigger_index + 0x01] = u8((start_stop_zone / 0x0000_0001) & 0xFF)
	ffb_destination[trigger_index + 0x02] = u8((start_stop_zone / 0x0000_0100) & 0xFF)
	ffb_destination[trigger_index + 0x03] = u8((force_zone / 0x0000_0001) & 0xFF)
	ffb_destination[trigger_index + 0x04] = u8((force_zone / 0x0000_0100) & 0xFF)
	ffb_destination[trigger_index + 0x05] = 0x00
	ffb_destination[trigger_index + 0x06] = 0x00
	ffb_destination[trigger_index + 0x07] = 0x00
	ffb_destination[trigger_index + 0x08] = 0x00
	ffb_destination[trigger_index + 0x09] = 0x00
	ffb_destination[trigger_index + 0x0A] = 0x00
}


//DualSenseTriggerGallop will not do any sanity checks
//Parameters:
//trigger_desc.params_0.x = start position (0 <= value <= 8)
//trigger_desc.params_0.y = end position (start position + 1 <= value <= 9)
//trigger_desc.params_0.z = first foot (0 <= value <= 6)
//trigger_desc.params_0.w = second foot (first foot + 1 <= value <= 7)
//trigger_desc.params_1.x = frequency_hz (value > 0)
DualSenseTriggerGallop :: proc "contextless" (trigger_desc : ^TriggerDescriptor, ffb_destination : []u8, $trigger_index : u8) #no_bounds_check {
	start_stop_zone := (1 << trigger_desc.params_0.x) | (1 << trigger_desc.params_0.y)
	time_ratio := (trigger_desc.params_0.z * 0x0000_0008) | (trigger_desc.params_0.w * 0x0000_0001)

	ffb_destination[trigger_index] = 0x23
	ffb_destination[trigger_index + 0x01] = u8((start_stop_zone / 0x0000_0001) & 0xFF)
	ffb_destination[trigger_index + 0x02] = u8((start_stop_zone / 0x0000_0100) & 0xFF)
	ffb_destination[trigger_index + 0x03] = u8((time_ratio / 0x0000_0001) & 0xFF)
	ffb_destination[trigger_index + 0x04] = u8(trigger_desc.params_1.x)
	ffb_destination[trigger_index + 0x05] = 0x00
	ffb_destination[trigger_index + 0x06] = 0x00
	ffb_destination[trigger_index + 0x07] = 0x00
	ffb_destination[trigger_index + 0x08] = 0x00
	ffb_destination[trigger_index + 0x09] = 0x00
	ffb_destination[trigger_index + 0x0A] = 0x00

}


//DualSenseTriggerMachine will not do any sanity checks
//Parameters:
//trigger_desc.params_0.x = start position (0 <= value <= 8)
//trigger_desc.params_0.y = end position (start position + 1 <= value <= 9)
//trigger_desc.params_0.z = amplitude_a (0 <= value <= 7)
//trigger_desc.params_0.w = amplitude_b (0 <= value <= 7)
//trigger_desc.params_1.x = frequency_hz (value > 0)
//trigger_desc.params_1.y = period (amplitude_a <= value <= amplitude_b) or vis versa
DualSenseTriggerMachine :: proc "contextless" (trigger_desc : ^TriggerDescriptor, ffb_destination : []u8, $trigger_index : u8) #no_bounds_check{

	start_stop_zone := (1 << trigger_desc.params_0.x) | (1 << trigger_desc.params_0.y)
	strength_zone := (trigger_desc.params_0.z * 0x0000_0001) | (trigger_desc.params_0.w * 0x0000_0008)

	ffb_destination[trigger_index] = 0x27
	ffb_destination[trigger_index + 0x01] = u8((start_stop_zone / 0x0000_0001) & 0xFF)
	ffb_destination[trigger_index + 0x02] = u8((start_stop_zone / 0x0000_0100) & 0xFF)
	ffb_destination[trigger_index + 0x03] = u8((strength_zone / 0x0000_0001) & 0xFF)
	ffb_destination[trigger_index + 0x04] = u8(trigger_desc.params_1.x)
	ffb_destination[trigger_index + 0x05] = u8(trigger_desc.params_1.y)
	ffb_destination[trigger_index + 0x06] = 0x00
	ffb_destination[trigger_index + 0x07] = 0x00
	ffb_destination[trigger_index + 0x08] = 0x00
	ffb_destination[trigger_index + 0x09] = 0x00
	ffb_destination[trigger_index + 0x0A] = 0x00
}


//Audio based.
DualSenseAudioHapticFeedback :: proc(){

	unimplemented("Audio Haptic Feedback is not implemented yet.")

}

//DualSenseRumble will not have any sanity checks
//Parameters:
//heavy strength is used as the weight for the "left" heavy emulated weight for the controller motor (0 <= value <= 0xFF)
//light strength is used as the weight for the "right" light emulated weight for the controller motor (0 <= value <= 0xFF)
DualSenseRumble :: proc "contextless" (light_strength : u8, heavy_strength : u8, output_buffer : []u8) #no_bounds_check{
	rumble_emulation_mask :u8 = output_buffer[0x00] & 0x01

	output_buffer[0x02] = light_strength >> rumble_emulation_mask
	output_buffer[0x03] = heavy_strength >> rumble_emulation_mask
}

//What are the parameter.
DualSenseVolume :: proc(headphone_volume : u8, speaker_volume : u8, output_buffer : []u8){
	//check allow volume bit/s if it is not set then set it.

	output_buffer[0x04] = headphone_volume
	output_buffer[0x05] = speaker_volume

}

DualSenseLight :: proc(){

	unimplemented("Dualsense Light is not implemented yet.")

}

///////////////////////////////////////////////////////////////////////////////////////////


///////////////////////////////////////////Xbox///////////////////////////////////////////

//XboxTriggerRumble will not have any sanity checks
//Parameters:
//trigger_desc.params_0.x = trigger rumble amount (0 <= value <= 255)
//Below Parameters are shared with Controller Rumble
//trigger_desc.params_0.y = rumble duration (0 <= value <= 0xFF)
//trigger_desc.params_0.z = rumble delay (0 <= value <= 0xFF)
//trigger_desc.params_0.w = rumble repeat count (0 <= value <= 0xFF)
XboxTriggerRumble :: #force_inline proc "contextless" (trigger_desc : ^TriggerDescriptor, $trigger : u8, output_buffer : []u8) #no_bounds_check{

	output_buffer[0x00] = 0x03

	output_buffer[0x01] = 0x0F

	when trigger == LEFT_TRIGGER{
		output_buffer[0x02] = u8(trigger_desc.params_0.x)

	}else{
		output_buffer[0x03] = u8(trigger_desc.params_0.x)
	}


	output_buffer[0x06] = u8(trigger_desc.params_0.y)
	output_buffer[0x07] = u8(trigger_desc.params_0.z)
	output_buffer[0x08] = u8(trigger_desc.params_0.w)
}

//XboxRumble will not have any sanity checks
//Parameters:
//trigger_desc.params_0.x = rumble amount (0 <= value <= 0xFF)
//Below Parameters are shared with Controller Trigger Rumble
//trigger_desc.params_0.y = rumble duration (0 <= value <= 0xFF)
//trigger_desc.params_0.z = rumble delay (0 <= value <= 0xFF)
//trigger_desc.params_0.w = rumble repeat count (0 <= value <= 0xFF)
XboxRumble :: proc(heavy_strength : u8, light_strength : u8, output_buffer : []u8){
	output_buffer[0x00] = 0x03

	output_buffer[0x01] = 0x0F

	output_buffer[0x04] = heavy_strength
	output_buffer[0x05] = light_strength

	output_buffer[0x06] = 0xFF
	output_buffer[0x07] = 0x00
	output_buffer[0x08] = 0x00
}

//XboxLed :: proc(){
	//Only supported on Elite controller.
//}
///////////////////////////////////////////////////////////////////////////////////////////

SendOutputToDevice :: proc(controller_property : ^CHIDProperty, buffer : []u8){
	if controller_property.vendor_id == HID_VENDOR_SONY && controller_property.input_byte_len == DUALSENSE_BT_INPUT_REPORT_LENGTH{
		//TODO:Khal remove vendor library create or use core CRC32 implementation.
		//This is used as a placeholder and will be removed when the test pass.
		crc := zlib.crc32(0, nil, 0)
		crc = zlib.crc32(0, &ps_output_crc32_seed, 1)
		crc = zlib.crc32(crc, raw_data(buffer), controller_property.output_byte_len - 4)

		buffer[0x4A] = u8((crc & 0x000000FF) / 0x0000_0001)
		buffer[0x4B] = u8((crc & 0x0000FF00) / 0x0000_0100)
		buffer[0x4C] = u8((crc & 0x00FF0000) / 0x0001_0000)
		buffer[0x4D] = u8((crc & 0xFF000000) / 0x0100_0000)
	}

	windows.WriteFile(controller_property.handle, raw_data(buffer), controller_property.output_byte_len, nil, nil)
}

CheckMatchCRC32 :: #force_inline proc "contextless" (buffer : [^]u8, seed : u8, len : u32, current_crc : u32) -> b32{
	local_seed := seed

	crc := zlib.crc32(0, nil, 0)
	crc = zlib.crc32(0, &local_seed, 1)
	crc = zlib.crc32(crc,buffer, len)

	return crc == current_crc
}

@(enable_target_feature="sse")
InternalApplyPostProcess :: proc(controller : ^GameController){

	//Radial Deadzone = 0.1
	//Axial Deadzone = 0.3
	//Anti Radial Deadzone = 0.2
	//Outer Deadzone Input = 1.0
	//Outer Deadzone Output = 1.0
	//Response Curve = 2.0
	//Trigger Deadzone = 76

	//We first convert from a vector u32 to vector i32, since converting a vector i32 to a vector f32 is always faster by a large margin.
	analog_sign :#simd[4]f32 = (#simd[4]f32)((#simd[4]i32)(intrinsics.simd_bit_or(intrinsics.simd_lanes_lt((^x86.__m128)(controller)^,{}), #simd[4]u32{1,1,1,1})))

	axial_deadzone : #simd[4]f32 = analog_sign * #simd[4]f32{0.3, 0.3, 0.5, 0.5}

	right_analog_abs_x : f32 = intrinsics.simd_extract(analog_sign, 2) * controller.right_analog_x
	right_analog_abs_y : f32 = intrinsics.simd_extract(analog_sign, 3) * controller.right_analog_y

	left_analog_magnitude_squared : f32 = (controller.left_analog_x * controller.left_analog_x) + (controller.left_analog_y * controller.left_analog_y)
	right_analog_magnitude_squared : f32 = (controller.right_analog_x * controller.right_analog_x) + (controller.right_analog_y * controller.right_analog_y)

	axial_left_analog_x : f32 = (controller.left_analog_x - intrinsics.simd_extract(axial_deadzone, 0)) * 1.4285714285714285714285714285714
	axial_left_analog_y : f32 = (controller.left_analog_y - intrinsics.simd_extract(axial_deadzone, 1)) * 1.4285714285714285714285714285714

	axial_right_analog_x : f32 = intrinsics.simd_extract(axial_deadzone, 2) * (right_analog_abs_x + right_analog_abs_y)
	axial_right_analog_y : f32 = intrinsics.simd_extract(axial_deadzone, 3) * (right_analog_abs_x + right_analog_abs_y)

	if left_analog_magnitude_squared < 0.01{
		controller.left_analog_x = 0
		controller.left_analog_y = 0
	}else{

		//Radial Deadzone
		left_analog_rcp_magnitude : f32 = intrinsics.simd_extract(x86._mm_rsqrt_ss(left_analog_magnitude_squared), 0)
		left_analog_magnitude : f32 = intrinsics.simd_extract(x86._mm_rcp_ss(left_analog_rcp_magnitude), 0) - 0.1 //Subtract RadialDeadzone

		//0.98765432098765432098765432098768 is pre-computed using the deadzone parameter above. We do this to save clock cycles (Change the parameter will require recompute. Changing some parameter will not make pre-computed value possible)
		output_magnitude : f32 = min(left_analog_magnitude * left_analog_magnitude * 0.98765432098765432098765432098768 + 0.2, 1.0)

		normalized_left_analog_x : f32 = controller.left_analog_x * left_analog_rcp_magnitude
		normalized_left_analog_y : f32 = controller.left_analog_y * left_analog_rcp_magnitude

		controller.left_analog_x = normalized_left_analog_x * output_magnitude
		controller.left_analog_y = normalized_left_analog_y * output_magnitude

		if abs(controller.left_analog_x) < 0.3{
			controller.left_analog_x = 0
		}else{
			controller.left_analog_x = axial_left_analog_x
		}

		if abs(controller.left_analog_y) < 0.3{
			controller.left_analog_y = 0
		}else{
			controller.left_analog_y = axial_left_analog_y
		}

		controller.left_analog_x = max(controller.left_analog_x, -1)
		controller.left_analog_y = max(controller.left_analog_y, -1)

	}

	if right_analog_magnitude_squared < 0.01{
		controller.right_analog_x = 0
		controller.right_analog_y = 0
	}else{
		//8 way
		if right_analog_abs_x > (right_analog_abs_y + right_analog_abs_y){
			controller.right_analog_y = 0
		}else if right_analog_abs_y > (right_analog_abs_x + right_analog_abs_x){
			controller.right_analog_x = 0
		}else{
			controller.right_analog_x = axial_right_analog_x
			controller.right_analog_y = axial_right_analog_y
		}

		controller.right_analog_x = max(controller.right_analog_x, -1)
		controller.right_analog_y = max(controller.right_analog_y, -1)

	}

}

ProcessControllerInput :: proc(vendor_id : u32, input_byte_len : u32 ,raw_input_buffer : [^]u8, controller : ^GameController) #no_bounds_check{
	if vendor_id == 0x5E{

		if raw_input_buffer[0x08] == GIP_DEVICE_INPUT_REPORT{

			button_action_remapping : u32 = (u32(raw_input_buffer[0x14]) & 0xFFFFFFF0) * 0x0000_0001 | (u32(raw_input_buffer[0x14]) & 0x0C) * 0x0000_0040 |  (u32(raw_input_buffer[0x15]) & 0xFFFFFFF0) * 0x0000_00040
			dpad_action_remapping : u32 = ((u32(raw_input_buffer[0x15]) & 0x01) * 0x0000_0001 | (u32(raw_input_buffer[0x15]) & 0x02) * 0x0000_0002)  | ((u32(raw_input_buffer[0x15]) & 0x08) / 0x0000_0004 | (u32(raw_input_buffer[0x15]) & 0x04) * 0x0000_0002)

			left_trigger : u32 = (u32(raw_input_buffer[0x16]) | (u32(raw_input_buffer[0x17]) * 0x0000_0100)) / 0x0000_0004
			right_trigger : u32 = (u32(raw_input_buffer[0x18]) | (u32(raw_input_buffer[0x19]) * 0x0000_0100)) / 0x0000_0004

			left_joystick_x : i32 =  i32(raw_input_buffer[0x1A]) | i32(i16(raw_input_buffer[0x1B]) * 0x0000_0100)
			left_joystick_y : i32 =  i32(raw_input_buffer[0x1C]) | i32(i16(raw_input_buffer[0x1D]) * 0x0000_0100)

			right_joystick_x : i32 = i32(raw_input_buffer[0x1E]) | i32(i16(raw_input_buffer[0x1F]) * 0x0000_0100)
			right_joystick_y : i32 = i32(raw_input_buffer[0x20]) | i32(i16(raw_input_buffer[0x21]) * 0x0000_0100)

			controller.left_analog_x = f32(left_joystick_x) * (1.0 / 32_767.0)
			controller.left_analog_y = f32(left_joystick_y) * (1.0 / 32_767.0)
			controller.right_analog_x = f32(right_joystick_x) * (1.0 / 32_767.0)
			controller.right_analog_y = f32(right_joystick_y) * (1.0 / 32_767.0)

			controller.left_trigger = left_trigger
			controller.right_trigger = right_trigger
			controller.buttons = button_action_remapping | dpad_action_remapping

		}else if raw_input_buffer[0x08] == GIP_DEVICE_STATUS{
			controller.battery_info = u32(raw_input_buffer[0x14]) & 0x0F
		}

		InternalApplyPostProcess(controller)

		return
	}

	raw_input_stride_buffer : [^]u8 = raw_input_buffer[0:]

	if input_byte_len == DUALSENSE_BT_INPUT_REPORT_LENGTH{
		//Khal Implement CRC32 validation for input Dualsense Bluetooth only
		//input_crc : u32 = (u32(raw_input_buffer[0x4A]) * 0x0000_0001) | (u32(raw_input_buffer[0x4B]) * 0x0000_0100) | (u32(raw_input_buffer[0x4C]) * 0x0000_0400) | (u32(raw_input_buffer[0x4D]) * 0x0004_0000)

		//if raw_input_buffer[0x00] == 0x31 && !CheckMatchCRC32(raw_input_buffer, ps_input_crc32_seed, PS_CRC_OFFSET, input_crc){
			//return
		//}


		raw_input_stride_buffer = raw_input_buffer[1:]
	}


	controller.left_analog_x = f32(i32(raw_input_stride_buffer[0x01]) - 0x80) * (1.0 / 127.0)
	controller.left_analog_y = f32(0x7F - i32(raw_input_stride_buffer[0x02])) * (1.0 / 127.0)
	controller.right_analog_x = f32(i32(raw_input_stride_buffer[0x03]) - 0x80) * (1.0 / 127.0)
	controller.right_analog_y = f32(0x7F - i32(raw_input_stride_buffer[0x04])) * (1.0 / 127.0)

	controller.left_trigger = u32(raw_input_stride_buffer[0x05])
	controller.right_trigger = u32(raw_input_stride_buffer[0x06])

	dpad_action_remapping : u32 = 1 << (u32(raw_input_stride_buffer[0x08]) / 0x0000_0002)
	button_action_remapping : u32 = ((u32(raw_input_stride_buffer[0x08]) & 0x10) * 0x04) | ((u32(raw_input_stride_buffer[0x08]) & 0x20) / 0x02) | ((u32(raw_input_stride_buffer[0x08]) & 0x40) / 0x02) | ((u32(raw_input_stride_buffer[0x08]) & 0x80) * 0x0000_0001)
	trigger_action_remapping : u32 = ((u32(raw_input_stride_buffer[0x09]) & 0x01) * 0x400) | ((u32(raw_input_stride_buffer[0x09]) & 0x02) * 0x400) | ((u32(raw_input_stride_buffer[0x09]) & 0x10) * 0x10) | ((u32(raw_input_stride_buffer[0x09]) & 0x20) * 0x10) | ((u32(raw_input_stride_buffer[0x09]) & 0x40) * 0x40) | ((u32(raw_input_stride_buffer[0x09]) & 0x80) * 0x40)


	controller.buttons = dpad_action_remapping | button_action_remapping | trigger_action_remapping

	if raw_input_stride_buffer[0x35] < 0x40 {

		battery_level : u32 = u32(raw_input_stride_buffer[0x35]) & 0xF
		battery_type : u32 =  u32(raw_input_stride_buffer[0x35]) & 0xF0

		controller.battery_info = (battery_level / 0x0000_0002 - 0x01) | battery_type
	}

	InternalApplyPostProcess(controller)
}


Win32ProcessBtnMsg :: proc(button : ^Button, flag : u32){
	if button.flag != flag{
		next_transition := button.transition + 1
		double_tap_elapsed := button.delta_ms - button.delta_threshold_ms

		button.flag = flag
		button.transition = next_transition & u32(double_tap_elapsed >> 31)
		button.delta_ms = 0
	}
}

//TODO:Khal better naming
Win32FlushInputReport :: proc(arena : ^virtual.Arena, game_input : ^GameInput){
	temp_arena := virtual.arena_temp_begin(arena)

	cbsize : u32
	windows.GetRawInputBuffer(nil, &cbsize, size_of(windows.RAWINPUTHEADER))
	cbsize <<= 4
	raw_input_slim_buffer, _ := virtual.make_multi_pointer(arena, [^]windows.RAWINPUT, cbsize / size_of(windows.RAWINPUT))

	for{
		cbsize_t := cbsize
		ninput := windows.GetRawInputBuffer(raw_input_slim_buffer, &cbsize_t, size_of(windows.RAWINPUTHEADER))

		if ninput == 0x0 || ninput == 0xFFFFFFFF{
			break
		}

		for input_index in 0..<ninput{

			raw_input := raw_input_slim_buffer[input_index]

			switch raw_input.header.dwType{
				case windows.RIM_TYPEMOUSE:
				{
					flag := i32(raw_input.data.mouse.DUMMYUNIONNAME.DUMMYSTRUCTNAME.usButtonFlags)

					if flag > 0 && flag < 9{
						Win32ProcessBtnMsg(&game_input.mouse_buttons, u32(flag))
					}
				}
				case windows.RIM_TYPEKEYBOARD:
				{
					//NOTE:khal MakeCode will change depending on input mapper struct that will be passed to this proc.
					//Mapper is responsible for remapping player input.

					flags := u32(raw_input.data.keyboard.Flags)
					scan_code := u32(raw_input.data.keyboard.MakeCode)

					if scan_code == 0x11{
						Win32ProcessBtnMsg(&game_input.action_buttons.x, flags) //up
					}else if scan_code == 0x1E{
						Win32ProcessBtnMsg(&game_input.action_buttons.y, flags) //left
					}else if scan_code == 0x1F{
						Win32ProcessBtnMsg(&game_input.action_buttons.z, flags) //down
					}else if scan_code == 0x20{
						Win32ProcessBtnMsg(&game_input.action_buttons.w, flags) //right
					}

					// store virtual key for input for text

					when ODIN_DEBUG{
						//Debug mode perf doesn't really matter

					}
				}
			}
		}
	}
	virtual.arena_temp_end(temp_arena)
}

//TODO: Handle Disconnecting previous controller that primary if this is called.
Win32ConnectPController :: proc(arena : ^virtual.Arena, controller_property : ^CHIDProperty){
	temp_arena := virtual.arena_temp_begin(arena)

	windows.CloseHandle(controller_property.handle)

	rawinput_count : u32

	windows.GetRawInputDeviceList(nil, &rawinput_count, size_of(windows.RAWINPUTDEVICELIST))

	rawinput_device_slim_buffer, _ := virtual.make_multi_pointer(arena, [^]windows.RAWINPUTDEVICELIST, rawinput_count)

	windows.GetRawInputDeviceList(rawinput_device_slim_buffer, &rawinput_count, size_of(windows.RAWINPUTDEVICELIST))

	for i in 0..<rawinput_count{

		rawinput_device := rawinput_device_slim_buffer[i]

		if rawinput_device.dwType == windows.RIM_TYPEHID{
			preparsed_size : u32

			windows.GetRawInputDeviceInfoW(rawinput_device.hDevice, RIDI_PREPARSEDATA, nil, &preparsed_size)

			preparsed_data,_ := virtual.make_multi_pointer(arena, [^]windows.HIDP_PREPARSED_DATA , preparsed_size)

			windows.GetRawInputDeviceInfoW(rawinput_device.hDevice, RIDI_PREPARSEDATA, preparsed_data, &preparsed_size)

			capabilities : windows.HIDP_CAPS
			windows.HidP_GetCaps(preparsed_data, &capabilities)

			if capabilities.Usage == windows.HID_USAGE_GENERIC_GAMEPAD && capabilities.UsagePage == windows.HID_USAGE_PAGE_GENERIC{

				device_handle : windows.HANDLE

				{
					hid_device_path_length : u32
					windows.GetRawInputDeviceInfoW(rawinput_device.hDevice, RIDI_DEVICENAME, nil, &hid_device_path_length)

					hid_device_path, _ := virtual.make_slice(arena, []u16, hid_device_path_length)
					windows.GetRawInputDeviceInfoW(rawinput_device.hDevice, RIDI_DEVICENAME, raw_data(hid_device_path), &hid_device_path_length)

					device_handle = windows.CreateFileW(raw_data(hid_device_path), windows.GENERIC_READ | windows.GENERIC_WRITE, windows.FILE_SHARE_READ | windows.FILE_SHARE_WRITE, nil, windows.OPEN_EXISTING, 0, nil)
				}

				attributes : windows.HIDD_ATTRIBUTES
				windows.HidD_GetAttributes(device_handle, &attributes)

				//Note:Khal Should we also check the product id for only Xbox one and Dualsense and not Xbox 360 and DualShock?
				if attributes.VendorID == HID_VENDOR_MICROSOFT{
					//GIP Protocol Setup

					controller_property.handle = windows.CreateFileW(&gip_path[0], windows.GENERIC_READ | windows.GENERIC_WRITE, windows.FILE_SHARE_READ | windows.FILE_SHARE_WRITE, nil, windows.OPEN_EXISTING, 0, nil)


					//windows.DeviceIoControl(controller_property.handle, 0x40001CD0, nil, 0, nil, 0,nil, nil)

					controller_property.vendor_id = 0x5E //HID_VENDOR_MICROSOFT
					controller_property.product_id = u32(attributes.ProductID)

					controller_property.input_byte_len = 1000
					controller_property.output_byte_len = 1000

					//TODO:khal not sure how to fetch the firm version using GIP Protocol.
					controller_property.firm_version = 0xFFFF_FFFF
				}else if attributes.VendorID == HID_VENDOR_SONY{
					//HID Protocol  Setup

					controller_property.handle = device_handle

					firmware_feature_slim_buffer,_ := virtual.make_multi_pointer(arena, [^]u8, DUALSENSE_FIRMWARE_FEATURE_REPORT_LENGTH)
					firmware_feature_slim_buffer[0x00] = 0x20

					//Seem like reading the firm_version will make BT use 0x31 input report, so we can skip write to make BT use 0x31 advance report rather then simplified report
					windows.HidD_GetFeature(device_handle, firmware_feature_slim_buffer, DUALSENSE_FIRMWARE_FEATURE_REPORT_LENGTH)

					controller_property.vendor_id = 0x4C//HID_VENDOR_SONY
					controller_property.product_id = u32(attributes.ProductID)

					if capabilities.InputReportByteLength == DUALSENSE_BT_INPUT_REPORT_LENGTH{

						controller_property.input_byte_len = DUALSENSE_BT_INPUT_REPORT_LENGTH
						controller_property.output_byte_len = DUALSENSE_BT_OUTPUT_REPORT_LENGTH

					}else if capabilities.InputReportByteLength == DUALSENSE_USB_INPUT_REPORT_LENGTH{

						controller_property.input_byte_len = DUALSENSE_USB_INPUT_REPORT_LENGTH
						controller_property.output_byte_len = DUALSENSE_USB_OUTPUT_REPORT_LENGTH
					}

					// version < 0x0224 then EnableRumbleEmulation else EnableImprovedRumbleEmulation
					controller_property.firm_version = u32(firmware_feature_slim_buffer[0x2C]) | (u32(firmware_feature_slim_buffer[0x2D]) << 0x8)

				}else{
					//Unsupported controller.
					windows.CloseHandle(device_handle)
				}
			}
		}
	}

	virtual.arena_temp_end(temp_arena)
}


Win32DisconnectPController :: proc(controller_property : ^CHIDProperty){
	//SetLed(game_input, 0, 0, 0, 0)
	//SetRumble(game_input, 0, 0)

	windows.CloseHandle(controller_property.handle)

	controller_property^ = {
		windows.INVALID_HANDLE,
		0,
		0,
		0,
		0,
		0,
		0,
	}
}

//Thread Priority High
InputEntryPoint :: proc(current_thread : ^thread.Thread){
	input_arena: virtual.Arena
	err := virtual.arena_init_static(&input_arena)

	//Input and Output report maybe be a large buffer when we implement GIP protocol for xbox. 500 bytes at minimum, 1000+ bytes recommended for safety
	input_buffer, _ := virtual.make_slice(&input_arena, []u8, 1000)
	output_buffer, _ := virtual.make_slice(&input_arena, []u8, 1000)

	controller_property : CHIDProperty
	game_input : GameInput

	#unroll for i in 0..<4{
		#no_bounds_check{
			game_input.action_buttons[i].delta_threshold_ms = 300 //button_thresholds_ms[i]
		}
	}

	//ctx : AudioContext

	res : Resource
	device : Device

	mem_desc := MemoryDescriptor{
	  static_reserve = 1024,
	  static_commit = 1024,
	  ring_size = 2048,
	  _padding_ = 0,
	}

  device_desc := DeviceDescriptor{
    flow = AudioStreamFlow.Render,
    role = AudioStreamRole.Console,
    category = AudioStreamCategory.GameMedia,
    periodicity = 0,

  }
	//JAInitContext(&ctx, 1)
	JA_InitBackend(&mem_desc, &res)
	fmt.printf("%i",res)
	JA_InitDevice(&device_desc, &res, &device) //TODO: Crashes here

	file,a := os.read_entire_file_from_filename("C:\\Users\\Dahir\\Desktop\\GitHub\\Odin-Journey\\journey\\test.wav");
	
	ress := JA_ValidateHeaderWAV(raw_data(file));

	decoder : Decoder
	JA_InitDecoder(windows.utf8_to_wstring("C:\\Users\\Dahir\\Desktop\\GitHub\\Odin-Journey\\journey\\test.wav"), 2, 6, &decoder)

	game_input.mouse_buttons.delta_threshold_ms = 300 //mouse_threshold_ms

	w_name := [8]u16{0x4D, 0x65, 0x73, 0x73, 0x61, 0x67, 0x65, 0x00}

	msg_window_handle := windows.CreateWindowExW(
		0x00,
		&w_name[0],
		nil,
		0x00,
		0x00,
		0x00,
		0x00,
		0x00,
		windows.HWND_MESSAGE,
		nil,
		nil,
		nil,
	)

	raw_input_devices : [3]windows.RAWINPUTDEVICE

	raw_input_devices.x = windows.RAWINPUTDEVICE{
		usUsagePage = windows.HID_USAGE_PAGE_GENERIC,
		usUsage = windows.HID_USAGE_GENERIC_GAMEPAD,
		dwFlags = 0x00,
		hwndTarget = msg_window_handle,
	}

	raw_input_devices.y = windows.RAWINPUTDEVICE{
		usUsagePage = windows.HID_USAGE_PAGE_GENERIC,
		usUsage = windows.HID_USAGE_GENERIC_MOUSE,
		dwFlags = windows.RIDEV_NOLEGACY,
		hwndTarget = msg_window_handle,
	}

	raw_input_devices.z = windows.RAWINPUTDEVICE{
		usUsagePage = windows.HID_USAGE_PAGE_GENERIC,
		usUsage = windows.HID_USAGE_GENERIC_KEYBOARD,
		dwFlags = windows.RIDEV_NOHOTKEYS | windows.RIDEV_NOLEGACY,
		hwndTarget = msg_window_handle,
	}

	windows.RegisterRawInputDevices(raw_data(raw_input_devices[:]), len(raw_input_devices), size_of(windows.RAWINPUTDEVICE))

	Win32ConnectPController(&input_arena, &controller_property)

	//TODO:Khal if the primary window is not focus then we don't send over input.
	for {
		current_counter := Win32GetTimeStamp()

		if windows.MsgWaitForMultipleObjects(0x01, cast(^windows.HANDLE)current_thread.data, false, windows.INFINITE, windows.QS_RAWINPUT) != (windows.WAIT_OBJECT_0 + 0x01){
			break
		}

		input_delta_time := Win32ElapsedTime(current_counter, MILLISECOND)

		windows.GetQueueStatus(windows.QS_RAWINPUT)

		if(!windows.ReadFile(controller_property.handle, raw_data(input_buffer), controller_property.input_byte_len, nil, nil)){
			Win32ConnectPController(&input_arena, &controller_property)
		}

		ProcessControllerInput(controller_property.vendor_id, controller_property.input_byte_len ,raw_data(input_buffer), &game_input.controller)

		#unroll for i in 0..<4{
			#no_bounds_check{
				game_input.action_buttons[i].delta_ms += i32(input_delta_time)
			}
		}

		game_input.mouse_buttons.delta_ms = i32(input_delta_time)

		Win32FlushInputReport(&input_arena, &game_input)


	}
	
	Win32DisconnectPController(&controller_property)

	raw_input_devices.x.dwFlags |= windows.RIDEV_REMOVE
	raw_input_devices.y.dwFlags |= windows.RIDEV_REMOVE
	raw_input_devices.z.dwFlags |= windows.RIDEV_REMOVE

	windows.RegisterRawInputDevices(raw_data(raw_input_devices[:]), len(raw_input_devices), size_of(windows.RAWINPUTDEVICE))

	windows.DestroyWindow(msg_window_handle)

	virtual.arena_free_all(&input_arena)
}
