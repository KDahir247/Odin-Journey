package journey
//Audio, Image, etc format


/*
	This file serves as a documentation for the current and future support audio and texture file.
	Refer to this file when parsing file to send to either the gpu or the audio stream.
	file format layout maybe erroneous and are subject to change.
	Before changing journey_audio, journey_texture change journey_format_type if there is any layout change or supporting a new hid device.

*/

//data stored in little endian


/*
	List Info Legend

IARL	The location where the subject of the file is archived
IART	The artist of the original subject of the file
ICMS	The name of the person or organization that commissioned the original subject of the file
ICMT	General comments about the file or its subject
ICOP	Copyright information about the file (e.g., "Copyright Some Company 2011")
ICRD	The date the subject of the file was created (creation date) (e.g., "2022-12-31")
ICRP	Whether and how an image was cropped
IDIM	The dimensions of the original subject of the file
IDPI	Dots per inch settings used to digitize the file
IENG	The name of the engineer who worked on the file
IGNR	The genre of the subject
IKEY	A list of keywords for the file or its subject
ILGT	Lightness settings used to digitize the file
IMED	Medium for the original subject of the file
INAM	Title of the subject of the file (name)
IPLT	The number of colors in the color palette used to digitize the file
IPRD	Name of the title the subject was originally intended for
ISBJ	Description of the contents of the file (subject)
ISFT	Name of the software package used to create the file
ISRC	The name of the person or organization that supplied the original subject of the file
ISRF	The original form of the material that was digitized (source form)
ITCH	The name of the technician who digitized the subject file

*/

WAV_FORMAT :: enum u16{
	WAVE_FORMAT_PCM = 0x0001,
	WAVE_FORMAT_IEEE_FLOAT = 0x0003,
	WAVE_FORMAT_ALAW = 0x0006,
	WAVE_FORMAT_MULAW = 0x0007,
	WAVE_FORMAT_EXTENSIBLE = 0xFFFE,
}


WAV_RIFF_HEADER :: struct #packed{
	chunk_id : u32,
	chunk_size : u32, //total chunk size
	wave_id : u32,
}

WAV_FMT_PCM_CHUNK :: struct #packed{
	chunk_id : u32,
	chunk_size : u32, //Should be set as 16 otherwise the fmt chunk isn't a PCM
	format_tag : WAV_FORMAT, //Should be set to WAVE_FORMAT_PCM
	channel_count : u16,
	sameples_per_sec : u32,
	average_byte_per_sec : u32,
	block_alignment : u16,
	bits_per_sample : u16
}


WAV_FMT_CHUNK :: struct #packed{
	chunk_id : u32,
	chunk_size : u32, //Should be set as 18 otherwise the fmt chunk isn't a non PCM
	format_tag : WAV_FORMAT,
	channels : u16,
	samples_per_sec : u32,
	average_byte_per_sec : u32,
	block_alignment : u16,
	size : u16,
}

WAV_FMT_EXT_CHUNK :: struct #packed{
	chunk_id : u32,
	chunk_size : u32, //Should be set as 40 otherwise the fmt chunk isn't a ext
	format_tag : WAV_FORMAT, //Should be set to WAVE_FORMAT_EXTENSIBLE
	channel_count : u16,
	samples_per_sec : u32,
	average_byte_per_sec : u32,
	block_alignment : u16,
	bit_per_sample : u16,
	extension_size : u16,
	valid_bits_per_sample : u16,
	channel_mask : u32,
	sub_format_high : u64,
	sub_format_low : u64,
}

WAV_FACT_CHUNK :: struct #packed{
	chunk_id : u32,
	chunk_size : u32, //Should be 4
	sample_legth : u32,
}

WAV_LIST_CHUNK :: struct #packed{
	chunk_id : u32,
	chunk_size : u32,
	chunk_type : u32, //Commonly set to INFO
	sub_chunk : u32, //Raw sub chunk buffer
}

WAV_SUB_CHUNK :: struct #packed{
	chunk_id : u32, //Refer to the legend above
	chunk_size : u32,
	data : u16, //Raw data list buffer 
}

WAV_DATA_CHUNK :: struct #packed{
	chunk_id : u32,
	chunk_size : u32,
	samples : u16, //Raw data buffer 
}

/*
	Order:

	RIFF HEADER
	FMT CHUNK
	LIST CHUNK (Optional)
	DATA CHUNK
*/

//--------------------------------------------------

OGG_HEADER :: enum u8{
	CONTINUATION = 0x01,
	BEGINNING_OF_STREAM = 0x02,
	END_OF_STREAM = 0x04,
}


OGG_PAGE :: struct #packed{
	magic_number : u32,  //must be OggS
	version : u8, //always zero
	header_type : OGG_HEADER,
	granule_position : u64,
	bit_stream_serial : u32,
	page_sequence_number : u32,
	check_sum : u32,
	page_segements : u8,

	segment_list : u8, //Raw segement buffer
}


OGG :: struct #packed{
	pages : OGG_PAGE //raw page buffer
}


//--------------------------------------------------





