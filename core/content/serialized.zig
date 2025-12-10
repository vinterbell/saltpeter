pub const TopLevelHeader = extern struct {
    magic: [4]u8,
    version: u32,
};

pub const magic: [4]u8 = "KNO3".*;
pub const latest_version: u32 = 0;

pub const Chunk = extern struct {
    chunk_type: [8]u8,
    chunk_version: u32,
    chunk_size: u32,
    // chunk_data: [chunk_size]u8,
};

// has info about the original filesystem path and metadata
pub const FilesystemAuthoringChunk0 = extern struct {
    pub const ty: [8]u8 = "FSAUTHOR".*;
    pub const version: u32 = 0;

    // is relative to content import root
    rel_path_len: u16,
    metadata_count: u16,
    // followed by [rel_path_len]u8 (utf-8 string of the relative path)
    // followed by [metadata_count]MetadataEntry

    pub const MetadataEntry = extern struct {
        key_len: u16,
        value_len: u16,
        // followed by [key_len]u8 (utf-8 string of the key)
        // followed by [value_len]u8 (utf-8 string of the value)
    };
};

pub const ImageChunk0 = extern struct {
    pub const ty: [8]u8 = "IMAGE   ".*;
    pub const version: u32 = 0;

    // ktx image data follows
};

pub const AudioChunk0 = extern struct {
    pub const ty: [8]u8 = "AUDIO   ".*;
    pub const version: u32 = 0;

    // opus audio data follows
};

pub const GeometryChunk0 = extern struct {
    pub const ty: [8]u8 = "GEOMETRY".*;
    pub const version: u32 = 0;

    vertex_count: u32,
    face_count: u32,
    // followed by [vertex_count]Vertex and [face_count]Face

    pub const Vertex = extern struct {
        position: [3]f32,
        normal: [3]f32,
        uv: [2]f32,
        tangent: [4]f32,
        vertex_color: [4]u8,
    };

    pub const Face = extern struct {
        a: u32,
        b: u32,
        c: u32,
    };
};

pub const LodChunk0 = extern struct {
    pub const ty: [8]u8 = "LODSINFO".*;
    pub const version: u32 = 0;

    lod_count: u16,
    // followed by [lod_count]u32 (offsets to each LOD level in the GeometryChunk)
};

pub const SkinningChunk0 = extern struct {
    pub const ty: [8]u8 = "SKINNING".*;
    pub const version: u32 = 0;

    weight_count: u32,
    joint_count: u16,
    name_table_size: u32,
    // followed by [weight_count]Weight and [joint_count]Joint
    // then [name_table_size]u8 (joint name strings)

    pub const Weight = extern struct {
        bone_indices: [4]u8,
        joint_weights: [4]f32,
    };

    pub const Joint = extern struct {
        joint_name_offset: u16,
        joint_name_length: u16,

        parent_index: u16, // if is 0xFFFF, then no parent
        lod_parent_index: u16, // if is 0xFFFF, then no LOD parent

        /// stores the distance to the furthest vertex influenced by this joint (used for culling)
        culling_radius: f32,
    };
};
