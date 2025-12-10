//! MIT License
//! Copyright (c) 2022 Alexandre Chêne
//!
//! Permission is hereby granted, free of charge, to any person obtaining a copy
//! of this software and associated documentation files (the "Software"), to deal
//! in the Software without restriction, including without limitation the rights
//! to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//! copies of the Software, and to permit persons to whom the Software is
//! furnished to do so, subject to the following conditions:
//!
//! The above copyright notice and this permission notice shall be included in all
//! copies or substantial portions of the Software.
//!
//! THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//! IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//! FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//! AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//! LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//! OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//! SOFTWARE.
const Gltf = @This();

pub const ParseError = error{
    InvalidGlbMagic,
    InvalidGlb,
    UnsupportedGltfVersion,
    InvalidGltf,
} || std.json.Error || std.json.ParseFromValueError || error{ BufferUnderrun, ValueTooLong };

pub const Data = struct {
    asset: Asset,
    scene: ?Index = null,
    scenes: []Scene,
    cameras: []Camera,
    nodes: []Node,
    meshes: []Mesh,
    materials: []Material,
    skins: []Skin,
    samplers: []TextureSampler,
    images: []Image,
    animations: []Animation,
    textures: []Texture,
    accessors: []Accessor,
    buffer_views: []BufferView,
    buffers: []Buffer,
    lights: []Light,
};

arena: std.heap.ArenaAllocator,
data: Data,

glb_binary: ?[]align(4) const u8 = null,

// types

/// Index of element in data arrays.
pub const Index = usize;

/// A node in the node hierarchy.
///
/// When the node contains skin, all mesh.primitives must contain
/// JOINTS_0 and WEIGHTS_0 attributes. A node may have either a matrix
/// or any combination of translation/rotation/scale (TRS) properties.
/// TRS properties are converted to matrices and postmultiplied in
/// the T * R * S order to compose the transformation matrix.
/// If none are provided, the transform is the identity.
///
/// When a node is targeted for animation (referenced by
/// an animation.channel.target), matrix must not be present.
pub const Node = struct {
    /// The user-defined name of this object.
    name: ?[]const u8 = null,
    /// The index of the node's parent.
    /// A node is called a root node when it doesn’t have a parent.
    parent: ?Index = null,
    /// The index of the mesh in this node.
    mesh: ?Index = null,
    /// The index of the camera referenced by this node.
    camera: ?Index = null,
    /// The index of the skin referenced by this node.
    skin: ?Index = null,
    /// The indices of this node’s children.
    children: []Index = &.{},
    /// A floating-point 4x4 transformation matrix stored in column-major order.
    matrix: ?[16]f32 = null,
    /// The node’s unit quaternion rotation in the order (x, y, z, w),
    /// where w is the scalar.
    rotation: [4]f32 = [_]f32{ 0, 0, 0, 1 },
    /// The node’s non-uniform scale, given as the scaling factors
    /// along the x, y, and z axes.
    scale: [3]f32 = [_]f32{ 1, 1, 1 },
    /// The node’s translation along the x, y, and z axes.
    translation: [3]f32 = [_]f32{ 0, 0, 0 },
    /// The weights of the instantiated morph target.
    /// The number of array elements must match the number of morph targets
    /// of the referenced mesh. When defined, mesh mush also be defined.
    weights: ?[]usize = null,
    ///The index of the light referenced by this node.
    light: ?Index = null,
    /// Any extra, custom attributes.
    extras: ?json.ObjectMap = null,
};

/// A buffer points to binary geometry, animation, or skins.
pub const Buffer = struct {
    /// Relative paths are relative to the current glTF asset.
    /// It could contains a data:-URI instead of a path.
    /// Note: data-uri isn't implemented in this library.
    uri: ?[]const u8 = null,
    /// The length of the buffer in bytes.
    byte_length: usize,
    /// Any extra, custom attributes.
    extras: ?json.ObjectMap = null,
};

/// A view into a buffer generally representing a subset of the buffer.
pub const BufferView = struct {
    /// The index of the buffer.
    buffer: Index,
    /// The length of the bufferView in bytes.
    byte_length: usize,
    /// The offset into the buffer in bytes.
    byte_offset: usize = 0,
    /// The stride, in bytes.
    byte_stride: ?usize = null,
    /// The hint representing the intended GPU buffer type
    /// to use with this buffer view.
    target: ?Target = null,
    /// Any extra, custom attributes.
    extras: ?json.ObjectMap = null,
};

/// A typed view into a buffer view that contains raw binary data.
pub const Accessor = struct {
    /// The index of the bufferView.
    buffer_view: ?Index = null,
    /// The offset relative to the start of the buffer view in bytes.
    byte_offset: usize = 0,
    /// The datatype of the accessor’s components.
    component_type: ComponentType,
    /// Specifies if the accessor’s elements are scalars, vectors, or matrices.
    type: AccessorType,
    /// The number of elements referenced by this accessor.
    count: usize,
    /// Specifies whether integer data values are normalized before usage.
    normalized: bool = false,
    /// Any extra, custom attributes.
    extras: ?json.ObjectMap = null,

    pub fn iterator(
        accessor: Accessor,
        comptime T: type,
        gltf: *const Gltf,
        binary: []align(4) const u8,
    ) AccessorIterator(T) {
        if (ComponentType.fromType(T) != accessor.component_type) {
            std.debug.panic(
                "Mismatch between gltf component '{}' and given type '{}'.",
                .{ accessor.component_type, T },
            );
        }

        if (accessor.buffer_view == null) {
            std.debug.panic("Accessors without buffer_view are not supported yet.", .{});
        }

        const buffer_view = gltf.data.buffer_views[accessor.buffer_view.?];

        const offset = (accessor.byte_offset + buffer_view.byte_offset) / @sizeOf(T);
        const datum_count: usize = accessor.type.componentCount();
        // When byte_stride is null, data is tightly packed, so stride = datum_count
        const stride = if (buffer_view.byte_stride) |byte_stride| (byte_stride / @sizeOf(T)) else datum_count;

        const total_count: usize = @intCast(accessor.count);

        const data: [*]const T = @ptrCast(@alignCast(binary.ptr));

        return .{
            .offset = offset,
            .stride = stride,
            .total_count = total_count,
            .datum_count = datum_count,
            .data = data,
            .current = 0,
        };
    }
};

/// Iterator over accessor elements
pub fn AccessorIterator(comptime T: type) type {
    return struct {
        offset: usize,
        stride: usize,
        total_count: usize,
        datum_count: usize,
        data: [*]const T,

        current: usize,

        /// Returns the next element of the accessor, or null if iteration is done.
        pub fn next(self: *@This()) ?[]const T {
            if (self.current >= self.total_count) return null;

            const slice = (self.data + self.offset + self.current * self.stride)[0..self.datum_count];
            self.current += 1;
            return slice;
        }

        /// Returns the next element of the accessor, or null if iteration is done. Does not change self.current.
        pub fn peek(self: *const @This()) ?[]const T {
            var copy = self.*;
            return copy.next();
        }

        /// Resets the iterator to the first element
        pub fn reset(self: *@This()) void {
            self.current = 0;
        }
    };
}

/// The root nodes of a scene.
pub const Scene = struct {
    /// The user-defined name of this object.
    name: ?[]const u8 = null,
    /// The indices of each root node.
    nodes: ?[]Index = null,
    /// Any extra, custom attributes.
    extras: ?json.ObjectMap = null,
};

/// Joints and matrices defining a skin.
pub const Skin = struct {
    /// The user-defined name of this object.
    name: ?[]const u8 = null,
    /// The index of the accessor containing the floating-point
    /// 4x4 inverse-bind matrices.
    inverse_bind_matrices: ?Index = null,
    /// The index of the node used as a skeleton root.
    skeleton: ?Index = null,
    /// Indices of skeleton nodes, used as joints in this skin.
    joints: []Index = &.{},
    /// Any extra, custom attributes.
    extras: ?json.ObjectMap = null,
};

/// Reference to a texture.
const TextureInfo = struct {
    /// The index of the texture.
    index: Index,
    /// The set index of texture’s TEXCOORD attribute
    /// used for texture coordinate mapping.
    texcoord: i32 = 0,
};

/// Reference to a normal texture.
const NormalTextureInfo = struct {
    /// The index of the texture.
    index: Index,
    /// The set index of texture’s TEXCOORD attribute
    /// used for texture coordinate mapping.
    texcoord: i32 = 0,
    /// The scalar parameter applied to each normal
    /// vector of the normal texture.
    scale: f32 = 1,
};

/// Reference to an occlusion texture.
const OcclusionTextureInfo = struct {
    /// The index of the texture.
    index: Index,
    /// The set index of texture’s TEXCOORD attribute
    /// used for texture coordinate mapping.
    texcoord: i32 = 0,
    /// A scalar multiplier controlling the amount of occlusion applied.
    strength: f32 = 1,
};

/// A set of parameter values that are used to define
/// the metallic-roughness material model
/// from Physically-Based Rendering methodology.
pub const MetallicRoughness = struct {
    /// The factors for the base color of the material.
    base_color_factor: [4]f32 = [_]f32{ 1, 1, 1, 1 },
    /// The base color texture.
    base_color_texture: ?TextureInfo = null,
    /// The factor for the metalness of the material.
    metallic_factor: f32 = 1,
    /// The factor for the roughness of the material.
    roughness_factor: f32 = 1,
    /// The metallic-roughness texture.
    metallic_roughness_texture: ?TextureInfo = null,
};

/// The material appearance of a primitive.
pub const Material = struct {
    /// The user-defined name of this object.
    name: ?[]const u8 = null,
    /// A set of parameter values that are used to define
    /// the metallic-roughness material model
    /// from Physically Based Rendering methodology.
    metallic_roughness: MetallicRoughness = .{},
    /// The tangent space normal texture.
    normal_texture: ?NormalTextureInfo = null,
    /// The occlusion texture.
    occlusion_texture: ?OcclusionTextureInfo = null,
    /// The emissive texture.
    emissive_texture: ?TextureInfo = null,
    /// The factors for the emissive color of the material.
    emissive_factor: [3]f32 = [_]f32{ 0, 0, 0 },
    /// The alpha rendering mode of the material.
    alpha_mode: AlphaMode = .@"opaque",
    /// The alpha cutoff value of the material.
    alpha_cutoff: f32 = 0.5,
    /// Specifies whether the material is double sided.
    /// If it's false, back-face culling is enabled.
    /// If it's true, back-face culling is disabled and
    /// double sided lighting is enabled.
    is_double_sided: bool = false,
    /// Emissive strength multiplier for the emissive factor/texture.
    /// Note: from khr_materials_emissive_strength extension.
    emissive_strength: f32 = 1.0,
    /// Index of refraction of material.
    /// Note: from khr_materials_ior extension.
    ior: f32 = 1.5,
    /// The factor for the transmission of the material.
    /// Note: from khr_materials_transmission extension.
    transmission_factor: f32 = 0.0,
    /// The transmission texture.
    /// Note: from khr_materials_transmission extension.
    transmission_texture: ?TextureInfo = null,
    /// The thickness of the volume beneath the surface.
    /// Note: from khr_materials_volume extension.
    thickness_factor: f32 = 0.0,
    /// A texture that defines the thickness, stored in the G channel.
    /// Note: from khr_materials_volume extension.
    thickness_texture: ?TextureInfo = null,
    /// Density of the medium.
    /// Note: from khr_materials_volume extension.
    attenuation_distance: f32 = std.math.inf(f32),
    /// The color that white light turns into due to absorption.
    /// Note: from khr_materials_volume extension.
    attenuation_color: [3]f32 = [_]f32{ 1, 1, 1 },
    /// The strength of the dispersion effect.
    /// Note: from khr_materials_dispersion extension.
    dispersion: f32 = 0.0,
    /// Any extra, custom attributes.
    extras: ?json.ObjectMap = null,
};

/// The material’s alpha rendering mode enumeration specifying
/// the interpretation of the alpha value of the base color.
pub const AlphaMode = enum {
    /// The alpha value is ignored, and the rendered output is fully opaque.
    @"opaque",
    /// The rendered output is either fully opaque or fully transparent
    /// depending on the alpha value and the specified alpha_cutoff value.
    /// Note: The exact appearance of the edges may be subject to
    /// implementation-specific techniques such as “Alpha-to-Coverage”.
    mask,
    /// The alpha value is used to composite the source and destination areas.
    /// The rendered output is combined with the background using
    /// the normal painting operation (i.e. the Porter and Duff over operator).
    blend,
};

/// A texture and its sampler.
pub const Texture = struct {
    /// The index of the sampler used by this texture.
    /// When undefined, a sampler with repeat wrapping and
    /// auto filtering should be used.
    sampler: ?Index = null,
    /// The index of the image used by this texture.
    /// When undefined, an extension or other mechanism should supply
    /// an alternate texture source, otherwise behavior is undefined.
    source: ?Index = null,
    /// Extension object with extension-specific objects.
    extensions: struct {
        EXT_texture_webp: ?struct {
            /// The index of the WebP image used by this texture.
            source: Index,
        } = null,
    } = .{},
    /// Any extra, custom attributes.
    extras: ?json.ObjectMap = null,
};

/// Image data used to create a texture.
/// Image may be referenced by an uri or a buffer view index.
pub const Image = struct {
    /// The user-defined name of this object.
    name: ?[]const u8 = null,
    /// The URI (or IRI) of the image.
    uri: ?[]const u8 = null,
    /// The image’s media type.
    /// This field must be defined when bufferView is defined.
    mime_type: ?[]const u8 = null,
    /// The index of the bufferView that contains the image.
    /// Note: This field must not be defined when uri is defined.
    buffer_view: ?Index = null,
    /// The image's data calculated from the buffer/buffer_view.
    /// Only there if glb file is loaded.
    data: ?[]const u8 = null,
    /// Any extra, custom attributes.
    extras: ?json.ObjectMap = null,
};

pub const WrapMode = enum(u32) {
    clamp_to_edge = 33071,
    mirrored_repeat = 33648,
    repeat = 10497,
};

pub const MinFilter = enum(u32) {
    nearest = 9728,
    linear = 9729,
    nearest_mipmap_nearest = 9984,
    linear_mipmap_nearest = 9985,
    nearest_mipmap_linear = 9986,
    linear_mipmap_linear = 9987,
};

pub const MagFilter = enum(u32) {
    nearest = 9728,
    linear = 9729,
};

/// Texture sampler properties for filtering and wrapping modes.
pub const TextureSampler = struct {
    /// Magnification filter.
    mag_filter: ?MagFilter = null,
    /// Minification filter.
    min_filter: ?MinFilter = null,
    /// S (U) wrapping mode.
    wrap_s: WrapMode = .repeat,
    /// T (U) wrapping mode.
    wrap_t: WrapMode = .repeat,
    /// Any extra, custom attributes.
    extras: ?json.ObjectMap = null,
};

/// Values are Accessor's index.
pub const Attribute = union(enum) {
    position: Index,
    normal: Index,
    tangent: Index,
    texcoord: Index,
    color: Index,
    joints: Index,
    weights: Index,

    pub fn index(self: Attribute) Index {
        return switch (self) {
            inline else => |v| v,
        };
    }
};

pub const AccessorType = enum {
    scalar,
    vec2,
    vec3,
    vec4,
    mat2x2,
    mat3x3,
    mat4x4,

    pub fn componentCount(self: AccessorType) usize {
        return switch (self) {
            .scalar => 1,
            .vec2 => 2,
            .vec3 => 3,
            .vec4 => 4,
            .mat2x2 => 4,
            .mat3x3 => 9,
            .mat4x4 => 16,
        };
    }
};

/// Enum values from GLTF 2.0 spec.
pub const Target = enum(u32) {
    array_buffer = 34962,
    element_array_buffer = 34963,
};

/// Enum values from GLTF 2.0 spec.
pub const ComponentType = enum(u32) {
    byte = 5120,
    unsigned_byte = 5121,
    short = 5122,
    unsigned_short = 5123,
    unsigned_integer = 5125,
    float = 5126,

    pub fn fromType(T: type) ComponentType {
        return switch (T) {
            i8 => .byte,
            u8 => .unsigned_byte,
            i16 => .short,
            u16 => .unsigned_short,
            u32 => .unsigned_integer,
            f32 => .float,
            else => @compileError("invalid type " ++ @typeName(T) ++ " for ComponentType.fromType"),
        };
    }

    pub fn byteSize(self: ComponentType) usize {
        return switch (self) {
            .byte => @sizeOf(i8),
            .unsigned_byte => @sizeOf(u8),
            .short => @sizeOf(i16),
            .unsigned_short => @sizeOf(u16),
            .unsigned_integer => @sizeOf(u32),
            .float => @sizeOf(f32),
        };
    }
};

/// The topology type of primitives to render.
pub const Mode = enum(u32) {
    points = 0,
    lines = 1,
    line_loop = 2,
    line_strip = 3,
    triangles = 4,
    triangle_strip = 5,
    triangle_fan = 6,
};

/// The name of the node’s TRS property to animate.
pub const TargetProperty = enum {
    /// For the "translation" property, the values that are provided by the
    /// sampler are the translation along the X, Y, and Z axes.
    translation,
    /// For the "rotation" property, the values are a quaternion
    /// in the order (x, y, z, w), where w is the scalar.
    rotation,
    /// For the "scale" property, the values are the scaling
    /// factors along the X, Y, and Z axes.
    scale,
    /// The "weights" of the Morph Targets it instantiates.
    weights,
};

/// An animation channel combines an animation sampler
/// with a target property being animated.
pub const Channel = struct {
    /// The index of a sampler in this animation used to
    /// compute the value for the target.
    sampler: Index,
    /// The descriptor of the animated property.
    target: struct {
        /// The index of the node to animate.
        /// When undefined, the animated object may be defined by an extension.
        node: Index,
        /// The name of the node’s TRS property to animate, or the "weights"
        /// of the Morph Targets it instantiates.
        property: TargetProperty,
    },
    /// Any extra, custom attributes.
    extras: ?json.ObjectMap = null,
};

/// Interpolation algorithm.
pub const Interpolation = enum {
    /// The animated values are linearly interpolated between keyframes.
    /// When targeting a rotation, spherical linear interpolation (slerp)
    /// should be used to interpolate quaternions.
    linear,
    /// The animated values remain constant to the output of the first
    /// keyframe, until the next keyframe.
    step,
    /// The animation’s interpolation is computed using a cubic
    /// spline with specified tangents.
    cubicspline,
};

/// An animation sampler combines timestamps
/// with a sequence of output values and defines an interpolation algorithm.
pub const AnimationSampler = struct {
    /// The index of an accessor containing keyframe timestamps.
    input: Index,
    /// The index of an accessor, containing keyframe output values.
    output: Index,
    /// Interpolation algorithm.
    interpolation: Interpolation = .linear,
    /// Any extra, custom attributes.
    extras: ?json.ObjectMap = null,
};

/// A keyframe animation.
pub const Animation = struct {
    /// The user-defined name of this object.
    name: ?[]const u8 = null,
    /// An array of animation channels.
    /// An animation channel combines an animation sampler with a target
    /// property being animated.
    /// Different channels of the same animation must not have the same targets.
    channels: []Channel = &.{},
    /// An array of animation samplers.
    /// An animation sampler combines timestamps with a sequence of output
    /// values and defines an interpolation algorithm.
    samplers: []AnimationSampler = &.{},
    /// Any extra, custom attributes.
    extras: ?json.ObjectMap = null,
};

/// Geometry to be rendered with the given material.
pub const Primitive = struct {
    attributes: []Attribute = &.{},
    /// The topology type of primitives to render.
    mode: Mode = .triangles,
    /// The index of the accessor that contains the vertex indices.
    indices: ?Index = null,
    /// The index of the material to apply to this primitive when rendering.
    material: ?Index = null,
    /// Any extra, custom attributes.
    extras: ?json.ObjectMap = null,
};

/// A set of primitives to be rendered.
/// Its global transform is defined by a node that references it.
pub const Mesh = struct {
    /// The user-defined name of this object.
    name: ?[]const u8 = null,
    /// An array of primitives, each defining geometry to be rendered.
    primitives: []Primitive = &.{},
    /// Any extra, custom attributes.
    extras: ?json.ObjectMap = null,
};

/// Metadata about the glTF asset.
pub const Asset = struct {
    /// The glTF version that this asset targets.
    version: []const u8,
    /// Tool that generated this glTF model. Useful for debugging.
    generator: ?[]const u8 = null,
    /// A copyright message suitable for display to credit the content creator.
    copyright: ?[]const u8 = null,
    /// Any extra, custom attributes.
    extras: ?json.ObjectMap = null,
};

/// A camera’s projection.
/// A node may reference a camera to apply a transform to place the camera
/// in the scene.
pub const Camera = struct {
    /// A perspective camera containing properties to create a
    /// perspective projection matrix.
    pub const Perspective = struct {
        /// The aspect ratio of the field of view.
        aspect_ratio: ?f32,
        /// The vertical field of view in radians.
        /// This value should be less than π.
        yfov: f32,
        /// The distance to the far clipping plane.
        zfar: ?f32,
        /// The distance to the near clipping plane.
        znear: f32,
    };

    /// An orthographic camera containing properties to create an
    /// orthographic projection matrix.
    pub const Orthographic = struct {
        /// The horizontal magnification of the view.
        /// This value must not be equal to zero.
        /// This value should not be negative.
        xmag: f32,
        /// The vertical magnification of the view.
        /// This value must not be equal to zero.
        /// This value should not be negative.
        ymag: f32,
        /// The distance to the far clipping plane.
        /// This value must not be equal to zero.
        /// This value must be greater than znear.
        zfar: f32,
        /// The distance to the near clipping plane.
        znear: f32,
    };

    name: ?[]const u8 = null,
    type: union(enum) {
        perspective: Perspective,
        orthographic: Orthographic,
    },
    /// Any extra, custom attributes.
    extras: ?json.ObjectMap = null,
};

/// Specifies the light type.
pub const LightType = enum {
    /// Directional lights act as though they are infinitely far away and emit light in the direction of the local -z axis.
    /// This light type inherits the orientation of the node that it belongs to; position and scale are ignored
    /// except for their effect on the inherited node orientation. Because it is at an infinite distance,
    /// the light is not attenuated. Its intensity is defined in lumens per metre squared, or lux (lm/m^2).
    directional,
    /// Point lights emit light in all directions from their position in space; rotation and scale are ignored except
    /// for their effect on the inherited node position.
    /// The brightness of the light attenuates in a physically correct manner as distance increases from
    /// the light's position (i.e. brightness goes like the inverse square of the distance).
    /// Point light intensity is defined in candela, which is lumens per square radian (lm/sr).
    point,
    /// Spot lights emit light in a cone in the direction of the local -z axis.
    /// The angle and falloff of the cone is defined using two numbers, the innerConeAngle and outerConeAngle.
    /// As with point lights, the brightness also attenuates in a physically correct manner as distance
    /// increases from the light's position (i.e. brightness goes like the inverse square of the distance).
    /// Spot light intensity refers to the brightness inside the innerConeAngle (and at the location of the light) and
    /// is defined in candela, which is lumens per square radian (lm/sr).
    ///
    /// Engines that don't support two angles for spotlights should use outerConeAngle as the spotlight angle,
    /// leaving innerConeAngle to implicitly be 0.
    spot,
};

/// A directional, point or spot light.
pub const Light = struct {
    name: ?[]const u8 = null,
    /// Color of the light source.
    color: [3]f32 = .{ 1, 1, 1 },
    /// Intensity of the light source. `point` and `spot` lights use luminous intensity in candela (lm/sr)
    /// while `directional` lights use illuminance in lux (lm/m^2).
    intensity: f32 = 1,
    /// Specifies the light type.
    type: LightType,
    /// When a light's type is spot, the spot property on the light is required.
    spot: ?LightSpot,
    /// A distance cutoff at which the light's intensity may be considered to have reached zero.
    range: f32,
    /// Any extra, custom attributes.
    extras: ?json.ObjectMap = null,
};

pub const LightSpot = struct {
    /// Angle in radians from centre of spotlight where falloff begins.
    inner_cone_angle: f32 = 0,
    /// Angle in radians from centre of spotlight where falloff ends.
    outer_cone_angle: f32 = std.math.pi / @as(f32, 4),
};

// impl

pub fn init(allocator: std.mem.Allocator) Gltf {
    return .{
        .arena = .init(allocator),
        .data = .{
            .asset = .{ .version = "Undefined" },
            .scenes = &.{},
            .nodes = &.{},
            .cameras = &.{},
            .meshes = &.{},
            .materials = &.{},
            .skins = &.{},
            .samplers = &.{},
            .images = &.{},
            .animations = &.{},
            .textures = &.{},
            .accessors = &.{},
            .buffer_views = &.{},
            .buffers = &.{},
            .lights = &.{},
        },
    };
}

/// Fill data by parsing a glTF file's buffer.
pub fn parse(self: *Gltf, file_buffer: []align(4) const u8) ParseError!void {
    if (isGlb(file_buffer)) {
        try self.parseGlb(file_buffer);
    } else {
        try self.parseGltfJson(file_buffer);
    }
}

pub fn debugPrint(self: *const Gltf) void {
    const print = std.debug.print;

    const msg =
        \\
        \\  glTF file info:
        \\
        \\    Node       {}
        \\    Mesh       {}
        \\    Skin       {}
        \\    Animation  {}
        \\    Texture    {}
        \\    Material   {}
        \\    Accessor   {}
        \\    BufferView {}
        \\    Buffer     {}
        \\    Camera     {}
        \\    Light      {}
        \\    Scene      {}
        \\
    ;

    print(msg, .{
        self.data.nodes.len,
        self.data.meshes.len,
        self.data.skins.len,
        self.data.animations.len,
        self.data.textures.len,
        self.data.materials.len,
        self.data.accessors.len,
        self.data.buffer_views.len,
        self.data.buffers.len,
        self.data.cameras.len,
        self.data.lights.len,
        self.data.scenes.len,
    });

    print("  Details:\n\n", .{});

    if (self.data.skins.len > 0) {
        print("   Skins found:\n", .{});

        for (self.data.skins) |skin| {
            print("     '{?s}' found with {} joint(s).\n", .{
                skin.name,
                skin.joints.len,
            });
        }

        print("\n", .{});
    }

    if (self.data.animations.len > 0) {
        print("  Animations found:\n", .{});

        for (self.data.animations) |anim| {
            print(
                "     '{?s}' found with {} sampler(s) and {} channel(s).\n",
                .{ anim.name, anim.samplers.len, anim.channels.len },
            );
        }

        print("\n", .{});
    }
}

/// Retrieve actual data from a glTF BufferView through a given glTF Accessor.
/// Note: This library won't pull to memory the binary buffer corresponding
/// to the BufferView.
pub fn getDataFromBufferView(
    self: *const Gltf,
    comptime T: type,
    allocator: std.mem.Allocator,
    accessor: Accessor,
    binary: []const u8,
) std.mem.Allocator.Error![]T {
    if (ComponentType.fromType(T) != accessor.component_type) {
        std.debug.panic(
            "Mismatch between gltf component '{}' and given type '{}'.",
            .{ accessor.component_type, T },
        );
    }

    if (accessor.buffer_view == null) {
        std.debug.panic("Accessors without buffer_view are not supported yet.", .{});
    }

    const buffer_view = self.data.buffer_views[accessor.buffer_view.?];

    const total_offset = accessor.byte_offset + buffer_view.byte_offset;

    const stride = if (buffer_view.byte_stride) |byte_stride| (byte_stride / @sizeOf(T)) else accessor.type.componentCount();

    const total_count = accessor.count;
    const datum_count = accessor.type.componentCount();

    const data: []const T = @ptrCast(@alignCast(binary[total_offset..]));
    var list = try std.ArrayList(T).initCapacity(allocator, total_count * datum_count);
    defer list.deinit(allocator);

    var current_count: usize = 0;
    while (current_count < total_count) : (current_count += 1) {
        const slice = data[current_count * stride ..][0..datum_count];
        list.appendSliceAssumeCapacity(slice);
    }

    return try list.toOwnedSlice(allocator);
}

pub fn deinit(self: *Gltf) void {
    self.arena.deinit();
}

pub fn getLocalTransform(node: *const Node) linalg.Mat {
    if (node.matrix) |mat4x4| {
        return .{
            mat4x4[0..4].*,
            mat4x4[4..8].*,
            mat4x4[8..12].*,
            mat4x4[12..16].*,
        };
    }

    const translate = linalg.translation(node.translation[0], node.translation[1], node.translation[2]);
    const rotate = linalg.matFromQuat(node.rotation);
    const scale = linalg.scaling(node.scale[0], node.scale[1], node.scale[2]);

    const trs = linalg.mul(translate, linalg.mul(rotate, scale));
    return trs;
}

pub fn getGlobalTransform(data: *const Data, node: *const Node) linalg.Mat {
    var parent_index_opt = node.parent;
    var node_transform: linalg.Mat = getLocalTransform(node);

    while (parent_index_opt) |parent_index| {
        const parent = data.nodes[parent_index];
        const parent_transform = getLocalTransform(parent);

        node_transform = linalg.mul(parent_transform, node_transform);
        parent_index_opt = parent.parent;
    }

    return node_transform;
}

fn isGlb(glb_buffer: []align(4) const u8) bool {
    const GLB_MAGIC_NUMBER: u32 = 0x46546C67; // 'gltf' in ASCII.
    const fields: [*]const u32 = @ptrCast(glb_buffer);

    return fields[0] == GLB_MAGIC_NUMBER;
}

fn parseGlb(self: *Gltf, glb_buffer: []align(4) const u8) !void {
    const GLB_CHUNK_TYPE_JSON: u32 = 0x4E4F534A; // 'JSON' in ASCII.
    const GLB_CHUNK_TYPE_BIN: u32 = 0x004E4942; // 'BIN' in ASCII.

    // Keep track of the moving index in the glb buffer.
    var index: usize = 0;

    // 'cause most of the interesting fields are u32s in the buffer, it's
    // easier to read them with a pointer cast.
    const fields: [*]const u32 = @ptrCast(glb_buffer);

    // The 12-byte header consists of three 4-byte entries:
    //  u32 magic
    //  u32 version
    //  u32 length
    const total_length = blk: {
        const header = fields[0..3];

        const version = header[1];
        const length = header[2];

        if (!isGlb(glb_buffer)) {
            return error.InvalidGlbMagic;
        }

        if (version != 2) {
            return error.UnsupportedGltfVersion;
        }

        index = header.len * @sizeOf(u32);
        break :blk length;
    };

    // Each chunk has the following structure:
    //  u32 chunkLength
    //  u32 chunkType
    //  ubyte[] chunkData
    const json_buffer = blk: {
        const json_chunk = fields[3..6];

        if (json_chunk[1] != GLB_CHUNK_TYPE_JSON) {
            return error.InvalidGlb;
        }

        const json_bytes: u32 = fields[3];
        const start = index + 2 * @sizeOf(u32);
        const end = start + json_bytes;

        const json_buffer = glb_buffer[start..end];

        index = end;
        break :blk json_buffer;
    };

    const binary_buffer = blk: {
        const fields_index = index / @sizeOf(u32);

        const binary_bytes = fields[fields_index];
        const start = index + 2 * @sizeOf(u32);
        const end = start + binary_bytes;

        std.debug.assert(end == total_length);

        std.debug.assert(start % 4 == 0);
        std.debug.assert(end % 4 == 0);
        const binary: []align(4) const u8 = @alignCast(glb_buffer[start..end]);

        if (fields[fields_index + 1] != GLB_CHUNK_TYPE_BIN) {
            // second chunk must be BIN
            return error.InvalidGlb;
        }

        index = end;
        break :blk binary;
    };

    try self.parseGltfJson(json_buffer);
    self.assignBinaryBuffer(binary_buffer);
}

pub fn assignBinaryBuffer(self: *Gltf, binary: []align(4) const u8) void {
    self.glb_binary = binary;

    const buffer_views = self.data.buffer_views;

    for (self.data.images) |*image| {
        if (image.buffer_view) |buffer_view_index| {
            const buffer_view = buffer_views[buffer_view_index];
            const start = buffer_view.byte_offset;
            const end = start + buffer_view.byte_length;
            image.data = binary[start..end];
        }
    }
}

fn parseGltfJson(self: *Gltf, gltf_json: []const u8) !void {
    const alloc = self.arena.allocator();

    var gltf_parsed = try json.parseFromSlice(json.Value, alloc, gltf_json, .{});
    defer gltf_parsed.deinit();

    const gltf: *json.Value = &gltf_parsed.value;

    if (gltf.object.get("asset")) |json_value| {
        var asset = &self.data.asset;

        if (json_value.object.get("version")) |version| {
            asset.version = version.string;
        } else {
            return error.InvalidGltf;
        }

        if (json_value.object.get("generator")) |generator| {
            asset.generator = generator.string;
        }

        if (json_value.object.get("copyright")) |copyright| {
            asset.copyright = copyright.string;
        }
    }

    if (gltf.object.get("nodes")) |nodes| {
        self.data.nodes = try alloc.alloc(Node, nodes.array.items.len);
        for (nodes.array.items, 0..) |item, index| {
            const object = item.object;

            var node = Node{};

            if (object.get("name")) |name| {
                node.name = name.string;
            }

            if (object.get("mesh")) |mesh| {
                node.mesh = try parseIndex(mesh);
            }

            if (object.get("camera")) |camera_index| {
                node.camera = try parseIndex(camera_index);
            }

            if (object.get("skin")) |skin| {
                node.skin = try parseIndex(skin);
            }

            if (object.get("children")) |children| {
                node.children = try alloc.alloc(Index, children.array.items.len);
                for (children.array.items, 0..) |value, child_index| {
                    node.children[child_index] = try parseIndex(value);
                }
            }

            if (object.get("rotation")) |rotation| {
                for (rotation.array.items, 0..) |component, i| {
                    node.rotation[i] = try parseFloat(f32, component);
                }
            }

            if (object.get("translation")) |translation| {
                for (translation.array.items, 0..) |component, i| {
                    node.translation[i] = try parseFloat(f32, component);
                }
            }

            if (object.get("scale")) |scale| {
                for (scale.array.items, 0..) |component, i| {
                    node.scale[i] = try parseFloat(f32, component);
                }
            }

            if (object.get("matrix")) |matrix| {
                node.matrix = [16]f32{
                    1, 0, 0, 0,
                    0, 1, 0, 0,
                    0, 0, 1, 0,
                    0, 0, 0, 1,
                };

                for (matrix.array.items, 0..) |component, i| {
                    node.matrix.?[i] = try parseFloat(f32, component);
                }
            }

            if (object.get("extensions")) |extensions| {
                if (extensions.object.get("KHR_lights_punctual")) |lights_punctual| {
                    if (lights_punctual.object.get("light")) |light| {
                        node.light = @intCast(light.integer);
                    }
                }
            }

            if (object.get("extras")) |extras| {
                node.extras = extras.object;
            }

            self.data.nodes[index] = node;
        }
    }

    if (gltf.object.get("cameras")) |cameras| {
        self.data.cameras = try alloc.alloc(Camera, cameras.array.items.len);
        for (cameras.array.items, 0..) |item, i| {
            const object = item.object;

            var camera = Camera{
                .type = undefined,
            };

            if (object.get("name")) |name| {
                camera.name = name.string;
            }

            if (object.get("extras")) |extras| {
                camera.extras = extras.object;
            }

            if (object.get("type")) |name| {
                if (std.mem.eql(u8, name.string, "perspective")) {
                    if (object.get("perspective")) |perspective| {
                        var value = perspective.object;

                        camera.type = .{
                            .perspective = .{
                                .aspect_ratio = if (value.get("aspectRatio")) |aspect_ratio| try parseFloat(
                                    f32,
                                    aspect_ratio,
                                ) else null,
                                .yfov = try parseFloat(f32, value.get("yfov").?),
                                .zfar = if (value.get("zfar")) |zfar| try parseFloat(
                                    f32,
                                    zfar,
                                ) else null,
                                .znear = try parseFloat(f32, value.get("znear").?),
                            },
                        };
                    } else {
                        return error.InvalidGltf; // Camera perspective missing
                    }
                } else if (std.mem.eql(u8, name.string, "orthographic")) {
                    if (object.get("orthographic")) |orthographic| {
                        var value = orthographic.object;

                        camera.type = .{
                            .orthographic = .{
                                .xmag = try parseFloat(f32, value.get("xmag").?),
                                .ymag = try parseFloat(f32, value.get("ymag").?),
                                .zfar = try parseFloat(f32, value.get("zfar").?),
                                .znear = try parseFloat(f32, value.get("znear").?),
                            },
                        };
                    } else {
                        return error.InvalidGltf; // Camera orthographic missing
                    }
                } else {
                    return error.InvalidGltf; // Camera type must be perspective or orthographic
                }
            }

            self.data.cameras[i] = camera;
        }
    }

    if (gltf.object.get("skins")) |skins| {
        self.data.skins = try alloc.alloc(Skin, skins.array.items.len);
        for (skins.array.items, 0..) |item, i| {
            const object = item.object;

            var skin = Skin{};

            if (object.get("name")) |name| {
                skin.name = name.string;
            }

            if (object.get("joints")) |joints| {
                skin.joints = try alloc.alloc(Index, joints.array.items.len);
                for (joints.array.items, 0..) |joint, joint_index| {
                    skin.joints[joint_index] = try parseIndex(joint);
                }
            }

            if (object.get("skeleton")) |skeleton| {
                skin.skeleton = try parseIndex(skeleton);
            }

            if (object.get("inverseBindMatrices")) |inv_bind_mat4| {
                skin.inverse_bind_matrices = try parseIndex(inv_bind_mat4);
            }

            if (object.get("extras")) |extras| {
                skin.extras = extras.object;
            }

            self.data.skins[i] = skin;
        }
    }

    if (gltf.object.get("meshes")) |meshes| {
        self.data.meshes = try alloc.alloc(Mesh, meshes.array.items.len);
        for (meshes.array.items, 0..) |item, i| {
            const object = item.object;

            var mesh: Mesh = .{};

            if (object.get("name")) |name| {
                mesh.name = name.string;
            }

            if (object.get("primitives")) |primitives| {
                mesh.primitives = try alloc.alloc(Primitive, primitives.array.items.len);
                for (primitives.array.items, 0..) |prim_item, prim_index| {
                    var primitive: Primitive = .{};

                    if (prim_item.object.get("mode")) |mode| {
                        primitive.mode = @enumFromInt(mode.integer);
                    }

                    if (prim_item.object.get("indices")) |indices| {
                        primitive.indices = try parseIndex(indices);
                    }

                    if (prim_item.object.get("material")) |material| {
                        primitive.material = try parseIndex(material);
                    }

                    if (prim_item.object.get("attributes")) |attributes| {
                        var list: std.ArrayList(Attribute) = try .initCapacity(alloc, attributes.object.count());
                        defer list.deinit(alloc);

                        if (attributes.object.get("POSITION")) |position| {
                            list.appendAssumeCapacity(.{
                                .position = try parseIndex(position),
                            });
                        }

                        if (attributes.object.get("NORMAL")) |normal| {
                            list.appendAssumeCapacity(.{
                                .normal = try parseIndex(normal),
                            });
                        }

                        if (attributes.object.get("TANGENT")) |tangent| {
                            list.appendAssumeCapacity(.{
                                .tangent = try parseIndex(tangent),
                            });
                        }

                        const texcoords = [_][]const u8{
                            "TEXCOORD_0",
                            "TEXCOORD_1",
                            "TEXCOORD_2",
                            "TEXCOORD_3",
                            "TEXCOORD_4",
                            "TEXCOORD_5",
                            "TEXCOORD_6",
                        };

                        for (texcoords) |tex_name| {
                            if (attributes.object.get(tex_name)) |texcoord| {
                                list.appendAssumeCapacity(.{
                                    .texcoord = try parseIndex(texcoord),
                                });
                            }
                        }

                        const joints = [_][]const u8{
                            "JOINTS_0",
                            "JOINTS_1",
                            "JOINTS_2",
                            "JOINTS_3",
                            "JOINTS_4",
                            "JOINTS_5",
                            "JOINTS_6",
                        };

                        for (joints) |joint_name| {
                            if (attributes.object.get(joint_name)) |joint| {
                                list.appendAssumeCapacity(.{
                                    .joints = try parseIndex(joint),
                                });
                            }
                        }

                        const weights = [_][]const u8{
                            "WEIGHTS_0",
                            "WEIGHTS_1",
                            "WEIGHTS_2",
                            "WEIGHTS_3",
                            "WEIGHTS_4",
                            "WEIGHTS_5",
                            "WEIGHTS_6",
                        };

                        for (weights) |weight_count| {
                            if (attributes.object.get(weight_count)) |weight| {
                                list.appendAssumeCapacity(.{
                                    .weights = try parseIndex(weight),
                                });
                            }
                        }

                        primitive.attributes = try list.toOwnedSlice(alloc);
                    }

                    if (prim_item.object.get("extras")) |extras| {
                        primitive.extras = extras.object;
                    }

                    mesh.primitives[prim_index] = primitive;
                }
            }

            if (object.get("extras")) |extras| {
                mesh.extras = extras.object;
            }

            self.data.meshes[i] = mesh;
        }
    }

    if (gltf.object.get("accessors")) |accessors| {
        self.data.accessors = try alloc.alloc(Accessor, accessors.array.items.len);
        for (accessors.array.items, 0..) |item, i| {
            const object = item.object;

            var accessor: Accessor = .{
                .component_type = undefined,
                .type = undefined,
                .count = undefined,
            };

            if (object.get("componentType")) |component_type| {
                accessor.component_type = @enumFromInt(component_type.integer);
            } else {
                return error.InvalidGltf; // Missing accessor componentType
            }

            if (object.get("count")) |count| {
                accessor.count = @intCast(count.integer);
            } else {
                return error.InvalidGltf; // Missing accessor count
            }

            if (object.get("type")) |accessor_type| {
                if (std.mem.eql(u8, accessor_type.string, "SCALAR")) {
                    accessor.type = .scalar;
                } else if (std.mem.eql(u8, accessor_type.string, "VEC2")) {
                    accessor.type = .vec2;
                } else if (std.mem.eql(u8, accessor_type.string, "VEC3")) {
                    accessor.type = .vec3;
                } else if (std.mem.eql(u8, accessor_type.string, "VEC4")) {
                    accessor.type = .vec4;
                } else if (std.mem.eql(u8, accessor_type.string, "MAT2")) {
                    accessor.type = .mat2x2;
                } else if (std.mem.eql(u8, accessor_type.string, "MAT3")) {
                    accessor.type = .mat3x3;
                } else if (std.mem.eql(u8, accessor_type.string, "MAT4")) {
                    accessor.type = .mat4x4;
                } else {
                    // panic("Accessor's type '{s}' is invalid.", .{accessor_type.string});
                    return error.InvalidGltf; // Invalid accessor type
                }
            } else {
                return error.InvalidGltf; // Missing accessor type
            }

            if (object.get("normalized")) |normalized| {
                accessor.normalized = normalized.bool;
            }

            if (object.get("bufferView")) |buffer_view| {
                accessor.buffer_view = try parseIndex(buffer_view);
            }

            if (object.get("byteOffset")) |byte_offset| {
                accessor.byte_offset = @intCast(byte_offset.integer);
            }

            if (object.get("extras")) |extras| {
                accessor.extras = extras.object;
            }

            self.data.accessors[i] = accessor;
        }
    }

    if (gltf.object.get("bufferViews")) |buffer_views| {
        self.data.buffer_views = try alloc.alloc(BufferView, buffer_views.array.items.len);
        for (buffer_views.array.items, 0..) |item, i| {
            const object = item.object;

            var buffer_view: BufferView = .{
                .buffer = undefined,
                .byte_length = undefined,
            };

            if (object.get("buffer")) |buffer| {
                buffer_view.buffer = try parseIndex(buffer);
            }

            if (object.get("byteLength")) |byte_length| {
                buffer_view.byte_length = @intCast(byte_length.integer);
            }

            if (object.get("byteOffset")) |byte_offset| {
                buffer_view.byte_offset = @intCast(byte_offset.integer);
            }

            if (object.get("byteStride")) |byte_stride| {
                buffer_view.byte_stride = @intCast(byte_stride.integer);
            }

            if (object.get("target")) |target| {
                buffer_view.target = @enumFromInt(target.integer);
            }

            if (object.get("extras")) |extras| {
                buffer_view.extras = extras.object;
            }

            self.data.buffer_views[i] = buffer_view;
        }
    }

    if (gltf.object.get("buffers")) |buffers| {
        self.data.buffers = try alloc.alloc(Buffer, buffers.array.items.len);
        for (buffers.array.items, 0..) |item, i| {
            const object = item.object;

            var buffer = Buffer{
                .byte_length = undefined,
            };

            if (object.get("uri")) |uri| {
                buffer.uri = uri.string;
            }

            if (object.get("byteLength")) |byte_length| {
                buffer.byte_length = @intCast(byte_length.integer);
            } else {
                // panic("Buffer's byteLength is missing.", .{});
                return error.InvalidGltf; // Missing buffer byteLength
            }

            if (object.get("extras")) |extras| {
                buffer.extras = extras.object;
            }

            self.data.buffers[i] = buffer;
        }
    }

    if (gltf.object.get("scene")) |default_scene| {
        self.data.scene = try parseIndex(default_scene);
    }

    if (gltf.object.get("scenes")) |scenes| {
        self.data.scenes = try alloc.alloc(Scene, scenes.array.items.len);
        for (scenes.array.items, 0..) |item, i| {
            const object = item.object;

            var scene = Scene{};

            if (object.get("name")) |name| {
                scene.name = name.string;
            }

            if (object.get("nodes")) |nodes| {
                scene.nodes = try alloc.alloc(Index, nodes.array.items.len);

                for (nodes.array.items, 0..) |node, node_index| {
                    scene.nodes.?[node_index] = try parseIndex(node);
                }
            }

            if (object.get("extras")) |extras| {
                scene.extras = extras.object;
            }

            self.data.scenes[i] = scene;
        }
    }

    if (gltf.object.get("materials")) |materials| {
        self.data.materials = try alloc.alloc(Material, materials.array.items.len);
        for (materials.array.items, 0..) |item, mat_index| {
            const object = item.object;

            var material: Material = .{};

            if (object.get("name")) |name| {
                material.name = name.string;
            }

            if (object.get("pbrMetallicRoughness")) |pbrMetallicRoughness| {
                var metallic_roughness: MetallicRoughness = .{};
                if (pbrMetallicRoughness.object.get("baseColorFactor")) |color_factor| {
                    for (color_factor.array.items, 0..) |factor, i| {
                        metallic_roughness.base_color_factor[i] = try parseFloat(f32, factor);
                    }
                }

                if (pbrMetallicRoughness.object.get("metallicFactor")) |factor| {
                    metallic_roughness.metallic_factor = try parseFloat(f32, factor);
                }

                if (pbrMetallicRoughness.object.get("roughnessFactor")) |factor| {
                    metallic_roughness.roughness_factor = try parseFloat(f32, factor);
                }

                if (pbrMetallicRoughness.object.get("baseColorTexture")) |texture_info| {
                    var base_color_texture: TextureInfo = .{
                        .index = undefined,
                    };

                    if (texture_info.object.get("index")) |index| {
                        base_color_texture.index = try parseIndex(index);
                    }

                    if (texture_info.object.get("texCoord")) |texcoord| {
                        base_color_texture.texcoord = @intCast(texcoord.integer);
                    }
                    metallic_roughness.base_color_texture = base_color_texture;
                }

                if (pbrMetallicRoughness.object.get("metallicRoughnessTexture")) |texture_info| {
                    var metallic_roughness_texture: TextureInfo = .{
                        .index = undefined,
                    };

                    if (texture_info.object.get("index")) |index| {
                        metallic_roughness_texture.index = try parseIndex(index);
                    }

                    if (texture_info.object.get("texCoord")) |texcoord| {
                        metallic_roughness_texture.texcoord = @intCast(texcoord.integer);
                    }
                    metallic_roughness.metallic_roughness_texture = metallic_roughness_texture;
                }

                material.metallic_roughness = metallic_roughness;
            }

            if (object.get("normalTexture")) |normal_texture| {
                var normal_texture_info: NormalTextureInfo = .{
                    .index = undefined,
                };

                if (normal_texture.object.get("index")) |index| {
                    normal_texture_info.index = try parseIndex(index);
                }

                if (normal_texture.object.get("texCoord")) |index| {
                    normal_texture_info.texcoord = @intCast(index.integer);
                }

                if (normal_texture.object.get("scale")) |scale| {
                    normal_texture_info.scale = try parseFloat(f32, scale);
                }
                material.normal_texture = normal_texture_info;
            }

            if (object.get("emissiveTexture")) |emissive_texture| {
                var emissive_texture_info: TextureInfo = .{
                    .index = undefined,
                };

                if (emissive_texture.object.get("index")) |index| {
                    emissive_texture_info.index = try parseIndex(index);
                }

                if (emissive_texture.object.get("texCoord")) |index| {
                    emissive_texture_info.texcoord = @intCast(index.integer);
                }

                material.emissive_texture = emissive_texture_info;
            }

            if (object.get("occlusionTexture")) |occlusion_texture| {
                var occlusion_texture_info: OcclusionTextureInfo = .{
                    .index = undefined,
                };

                if (occlusion_texture.object.get("index")) |index| {
                    occlusion_texture_info.index = try parseIndex(index);
                }

                if (occlusion_texture.object.get("texCoord")) |index| {
                    occlusion_texture_info.texcoord = @intCast(index.integer);
                }

                if (occlusion_texture.object.get("strength")) |strength| {
                    occlusion_texture_info.strength = try parseFloat(f32, strength);
                }

                material.occlusion_texture = occlusion_texture_info;
            }

            if (object.get("alphaMode")) |alpha_mode| {
                if (std.mem.eql(u8, alpha_mode.string, "OPAQUE")) {
                    material.alpha_mode = .@"opaque";
                }
                if (std.mem.eql(u8, alpha_mode.string, "MASK")) {
                    material.alpha_mode = .mask;
                }
                if (std.mem.eql(u8, alpha_mode.string, "BLEND")) {
                    material.alpha_mode = .blend;
                }
            }

            if (object.get("doubleSided")) |double_sided| {
                material.is_double_sided = double_sided.bool;
            }

            if (object.get("alphaCutoff")) |alpha_cutoff| {
                material.alpha_cutoff = try parseFloat(f32, alpha_cutoff);
            }

            if (object.get("emissiveFactor")) |emissive_factor| {
                for (emissive_factor.array.items, 0..) |factor, i| {
                    material.emissive_factor[i] = try parseFloat(f32, factor);
                }
            }

            if (object.get("extensions")) |extensions| {
                if (extensions.object.get("KHR_materials_emissive_strength")) |materials_emissive_strength| {
                    if (materials_emissive_strength.object.get("emissiveStrength")) |emissive_strength| {
                        material.emissive_strength = try parseFloat(f32, emissive_strength);
                    }
                }

                if (extensions.object.get("KHR_materials_ior")) |materials_ior| {
                    if (materials_ior.object.get("ior")) |ior| {
                        material.ior = try parseFloat(f32, ior);
                    }
                }

                if (extensions.object.get("KHR_materials_transmission")) |materials_transmission| {
                    if (materials_transmission.object.get("transmissionFactor")) |transmission_factor| {
                        material.transmission_factor = try parseFloat(f32, transmission_factor);
                    }

                    if (materials_transmission.object.get("transmissionTexture")) |transmission_texture| {
                        var transmission_texture_info: TextureInfo = .{
                            .index = undefined,
                        };

                        if (transmission_texture.object.get("index")) |index| {
                            transmission_texture_info.index = try parseIndex(index);
                        }

                        if (transmission_texture.object.get("texCoord")) |index| {
                            transmission_texture_info.texcoord = @intCast(index.integer);
                        }

                        material.transmission_texture = transmission_texture_info;
                    }
                }

                if (extensions.object.get("KHR_materials_volume")) |materials_volume| {
                    if (materials_volume.object.get("thicknessFactor")) |thickness_factor| {
                        material.thickness_factor = try parseFloat(f32, thickness_factor);
                    }

                    if (materials_volume.object.get("thicknessTexture")) |thickness_texture| {
                        var thickness_texture_info: TextureInfo = .{
                            .index = undefined,
                        };

                        if (thickness_texture.object.get("index")) |index| {
                            thickness_texture_info.index = try parseIndex(index);
                        }

                        if (thickness_texture.object.get("texCoord")) |index| {
                            thickness_texture_info.texcoord = @intCast(index.integer);
                        }

                        material.thickness_texture = thickness_texture_info;
                    }

                    if (materials_volume.object.get("attenuationDistance")) |attenuation_distance| {
                        material.attenuation_distance = try parseFloat(f32, attenuation_distance);
                    }

                    if (materials_volume.object.get("attenuationColor")) |attenuation_color| {
                        for (&material.attenuation_color, attenuation_color.array.items) |*dst, src| {
                            dst.* = try parseFloat(f32, src);
                        }
                    }
                }

                if (extensions.object.get("KHR_materials_dispersion")) |materials_dispersion| {
                    if (materials_dispersion.object.get("dispersion")) |dispersion| {
                        material.dispersion = try parseFloat(f32, dispersion);
                    }
                }
            }

            if (object.get("extras")) |extras| {
                material.extras = extras.object;
            }

            self.data.materials[mat_index] = material;
        }
    }

    if (gltf.object.get("textures")) |textures| {
        self.data.textures = try alloc.alloc(Texture, textures.array.items.len);
        for (textures.array.items, 0..) |item, i| {
            var texture = Texture{};

            if (item.object.get("source")) |source| {
                texture.source = try parseIndex(source);
            }

            if (item.object.get("sampler")) |sampler| {
                texture.sampler = try parseIndex(sampler);
            }

            if (item.object.get("extensions")) |extension| {
                if (extension.object.get("EXT_texture_webp")) |webp| {
                    if (webp.object.get("source")) |source| {
                        texture.extensions.EXT_texture_webp = .{ .source = try parseIndex(source) };
                    }
                }
            }

            if (item.object.get("extras")) |extras| {
                texture.extras = extras.object;
            }

            self.data.textures[i] = texture;
        }
    }

    if (gltf.object.get("animations")) |animations| {
        self.data.animations = try alloc.alloc(Animation, animations.array.items.len);
        for (animations.array.items, 0..) |item, i| {
            const object = item.object;

            var animation = Animation{};

            if (item.object.get("name")) |name| {
                animation.name = name.string;
            }

            if (object.get("samplers")) |samplers| {
                animation.samplers = try alloc.alloc(AnimationSampler, samplers.array.items.len);
                for (samplers.array.items, 0..) |sampler_item, smapler_index| {
                    var sampler: AnimationSampler = .{
                        .input = undefined,
                        .output = undefined,
                    };

                    if (sampler_item.object.get("input")) |input| {
                        sampler.input = try parseIndex(input);
                    } else {
                        return error.InvalidGltf; // Missing animation sampler input
                    }

                    if (sampler_item.object.get("output")) |output| {
                        sampler.output = try parseIndex(output);
                    } else {
                        return error.InvalidGltf; // Missing animation sampler output
                    }

                    if (sampler_item.object.get("interpolation")) |interpolation| {
                        if (std.mem.eql(u8, interpolation.string, "LINEAR")) {
                            sampler.interpolation = .linear;
                        }

                        if (std.mem.eql(u8, interpolation.string, "STEP")) {
                            sampler.interpolation = .step;
                        }

                        if (std.mem.eql(u8, interpolation.string, "CUBICSPLINE")) {
                            sampler.interpolation = .cubicspline;
                        }
                    }

                    if (sampler_item.object.get("extras")) |extras| {
                        sampler.extras = extras.object;
                    }

                    animation.samplers[smapler_index] = sampler;
                }
            }

            if (object.get("channels")) |channels| {
                animation.channels = try alloc.alloc(Channel, channels.array.items.len);
                for (channels.array.items, 0..) |channel_item, channel_index| {
                    var channel: Channel = .{ .sampler = undefined, .target = .{
                        .node = undefined,
                        .property = undefined,
                    } };

                    if (channel_item.object.get("sampler")) |sampler_index| {
                        channel.sampler = try parseIndex(sampler_index);
                    } else {
                        return error.InvalidGltf; // Missing animation channel sampler
                    }

                    if (channel_item.object.get("target")) |target_item| {
                        if (target_item.object.get("node")) |node_index| {
                            channel.target.node = try parseIndex(node_index);
                        } else {
                            return error.InvalidGltf; // Missing animation target node
                        }

                        if (target_item.object.get("path")) |path| {
                            if (std.mem.eql(u8, path.string, "translation")) {
                                channel.target.property = .translation;
                            } else if (std.mem.eql(u8, path.string, "rotation")) {
                                channel.target.property = .rotation;
                            } else if (std.mem.eql(u8, path.string, "scale")) {
                                channel.target.property = .scale;
                            } else if (std.mem.eql(u8, path.string, "weights")) {
                                channel.target.property = .weights;
                            } else {
                                return error.InvalidGltf; // Animation path/property invalid
                            }
                        } else {
                            return error.InvalidGltf; // Animation target path missing
                        }
                    } else {
                        return error.InvalidGltf; // Animation channel target missing
                    }

                    if (channel_item.object.get("extras")) |extras| {
                        channel.extras = extras.object;
                    }

                    animation.channels[channel_index] = channel;
                }
            }

            if (object.get("extras")) |extras| {
                animation.extras = extras.object;
            }

            self.data.animations[i] = animation;
        }
    }

    if (gltf.object.get("samplers")) |samplers| {
        self.data.samplers = try alloc.alloc(TextureSampler, samplers.array.items.len);
        for (samplers.array.items, 0..) |item, i| {
            const object = item.object;
            var sampler = TextureSampler{};

            if (object.get("magFilter")) |mag_filter| {
                sampler.mag_filter = @enumFromInt(mag_filter.integer);
            }

            if (object.get("minFilter")) |min_filter| {
                sampler.min_filter = @enumFromInt(min_filter.integer);
            }

            if (object.get("wrapS")) |wrap_s| {
                sampler.wrap_s = @enumFromInt(wrap_s.integer);
            }

            if (object.get("wrapt")) |wrap_t| {
                sampler.wrap_t = @enumFromInt(wrap_t.integer);
            }

            if (object.get("extras")) |extras| {
                sampler.extras = extras.object;
            }

            self.data.samplers[i] = sampler;
        }
    }

    if (gltf.object.get("images")) |images| {
        self.data.images = try alloc.alloc(Image, images.array.items.len);
        for (images.array.items, 0..) |item, i| {
            const object = item.object;
            var image = Image{};

            if (object.get("name")) |name| {
                image.name = name.string;
            }

            if (object.get("uri")) |uri| {
                image.uri = uri.string;
            }

            if (object.get("mimeType")) |mime_type| {
                image.mime_type = mime_type.string;
            }

            if (object.get("bufferView")) |buffer_view| {
                image.buffer_view = try parseIndex(buffer_view);
            }

            if (object.get("extras")) |extras| {
                image.extras = extras.object;
            }

            self.data.images[i] = image;
        }
    }

    if (gltf.object.get("extensions")) |extensions| {
        if (extensions.object.get("KHR_lights_punctual")) |lights_punctual| {
            if (lights_punctual.object.get("lights")) |lights| {
                self.data.lights = try alloc.alloc(Light, lights.array.items.len);
                for (lights.array.items, 0..) |item, light_index| {
                    const object: json.ObjectMap = item.object;

                    var light = Light{
                        .type = undefined,
                        .range = std.math.inf(f32),
                        .spot = null,
                    };

                    if (object.get("name")) |name| {
                        light.name = name.string;
                    }

                    if (object.get("color")) |color| {
                        for (color.array.items, 0..) |component, i| {
                            light.color[i] = try parseFloat(f32, component);
                        }
                    }

                    if (object.get("intensity")) |intensity| {
                        light.intensity = try parseFloat(f32, intensity);
                    }

                    if (object.get("type")) |@"type"| {
                        if (std.meta.stringToEnum(LightType, @"type".string)) |light_type| {
                            light.type = light_type;
                        } else return error.InvalidGltf; // Light's type invalid
                    }

                    if (object.get("range")) |range| {
                        light.range = try parseFloat(f32, range);
                    }

                    if (object.get("spot")) |spot| {
                        light.spot = .{};

                        if (spot.object.get("innerConeAngle")) |inner_cone_angle| {
                            light.spot.?.inner_cone_angle = try parseFloat(f32, inner_cone_angle);
                        }

                        if (spot.object.get("outerConeAngle")) |outer_cone_angle| {
                            light.spot.?.outer_cone_angle = try parseFloat(f32, outer_cone_angle);
                        }
                    }

                    if (object.get("extras")) |extras| {
                        light.extras = extras.object;
                    }

                    self.data.lights[light_index] = light;
                }
            }
        }
    }

    // For each node, fill parent indexes.
    for (self.data.scenes) |scene| {
        if (scene.nodes) |nodes| {
            for (nodes) |node_index| {
                const node = &self.data.nodes[node_index];
                fillParents(&self.data, node, node_index);
            }
        }
    }
}

// In 'gltf' files, often values are array indexes;
// this function casts Integer to 'usize'.
fn parseIndex(component: json.Value) !usize {
    return switch (component) {
        .integer => |val| @intCast(val),
        else => error.InvalidGltf, // Not a valid index
    };
}

// Exact values could be interpreted as Integer, often we want only
// floating numbers.
fn parseFloat(comptime T: type, component: json.Value) !T {
    const type_info = @typeInfo(T);
    if (type_info != .float) {
        std.debug.panic(
            "Given type '{any}' is not a floating number.",
            .{type_info},
        );
    }

    return switch (component) {
        .float => |val| @floatCast(val),
        .integer => |val| @floatFromInt(val),
        else => error.InvalidGltf, // Not a valid number
    };
}

fn fillParents(data: *Data, node: *Node, parent_index: Index) void {
    for (node.children) |child_index| {
        var child_node = &data.nodes[child_index];
        child_node.parent = parent_index;
        fillParents(data, child_node, child_index);
    }
}

const std = @import("std");
const json = @import("std").json;

const linalg = @import("../math/linalg.zig");
