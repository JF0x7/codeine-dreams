using System.Collections.Generic;
using Godot;
namespace Portals3D;

[Tool]
public partial class PortalBoxMesh : ArrayMesh
{
	private Vector3 _size = new(1.0f, 1.0f, 1.0f);
	[Export]
	public Vector3 Size
	{
		get => _size;
		set
		{
			_size = value;
			GeneratePortalMesh();
		}
	}

	private void Init()
	{
		if (Engine.IsEditorHint())
		{
			GeneratePortalMesh();
		}
	}

	private void GeneratePortalMesh()
	{
		ulong startTime = Time.GetTicksUsec();
		ClearSurfaces();

		Godot.Collections.Array surfaceArray = [];
		surfaceArray.Resize((int)ArrayType.Max);

		List<Vector3> vertices = [];
		List<Vector2> uvs = [];
		List<Vector3> normals = [];
		List<int> indices = [];

		float w = Size.X / 2.0f;
		float h = Size.Y / 2.0f;
		Vector3 depth = new(0.0f, 0.0f, -Size.Z);

		Vector3 TopLeft = new(-w, h, 0.0f);
		Vector3 TopRight = new(w, h, 0.0f);
		Vector3 BottomLeft = new(-w, -h, 0.0f);
		Vector3 BottomRight = new(w, -h, 0.0f);

		vertices.AddRange
		([
			TopLeft, TopRight, BottomLeft, BottomRight,
			TopLeft + depth, TopRight + depth, BottomLeft + depth, BottomRight + depth,
		]);

		uvs.AddRange
		([
			Vector2.Zero, Vector2.Right, Vector2.Down, Vector2.One, // Front UVs
			Vector2.Zero, Vector2.Right, Vector2.Down, Vector2.One, // Back UVs
		]);

		normals.AddRange
		([
			Vector3.Back, Vector3.Back, Vector3.Back, Vector3.Back,
			Vector3.Back, Vector3.Back, Vector3.Back, Vector3.Back,
		]);

		// 0 ----------- 1
		// | \         / |
		// |  4-------5  |
		// |  |       |  |
		// |  |       |  |
		// |  6-------7  |
		// | /         \ |
		// 2 ----------- 3

		// Triangles are clockwise!

		indices.AddRange
		([
			0, 1, 4,
			4, 1, 5, // Top section

			1, 3, 5,
			5, 3, 7, // Right section

			3, 2, 7,
			7, 2, 6, // Bottom section

			2, 0, 6,
			6, 0, 4, // Left section

			4, 5, 6,
			6, 5, 7, // Back section 
			
			0, 1, 2,
			2, 1, 3, // Front section
		]);

		surfaceArray[(int)ArrayType.Vertex] = vertices.ToArray();
		surfaceArray[(int)ArrayType.TexUV] = uvs.ToArray();
		surfaceArray[(int)ArrayType.Normal] = normals.ToArray();
		surfaceArray[(int)ArrayType.Index] = indices.ToArray();

		AddSurfaceFromArrays(PrimitiveType.Triangles, surfaceArray);
	}
}
