#if TOOLS
using System.Linq;
using Godot;
namespace Portals3D;

[Tool]
public partial class PortalForwardDirection : EditorNode3DGizmoPlugin
{
	private const string GizmoName = "PortalForwardDirectionGizmo";
	private bool _isInitialized = false;

	public PortalForwardDirection()
	{
		// Initialize material using Initialize() method to prevent lifecycle racing.
	}

	// Prevent lifecycle racing by giving portal settings creation some time to complete.
	private void Initialize()
	{
		Color color = (Color)PortalSettings.GetSetting(Plugin.GizmoForwardColor);
		CreateMaterial(Plugin.GizmoForwardColor, color, false, false, false);

		_isInitialized = true;
	}

	public override string _GetGizmoName()
	{
		return GizmoName;
	}

	public override bool _HasGizmo(Node3D forNode3D)
	{
		return forNode3D is Portal3D;
	}

	public override void _Redraw(EditorNode3DGizmo gizmo)
	{
		Portal3D portal = gizmo.GetNode3D() as Portal3D;
		Godot.Collections.Array<Node> nodes = EditorInterface.Singleton.GetSelection().GetSelectedNodes();
		bool active = nodes.Contains(portal);

		gizmo.Clear();

		Godot.Collections.Array<Vector3> lines = [
			Vector3.Zero,
			Vector3.Back
		];

		if (active)
		{
			float arrowSpread = 0.05f;
			lines.AddRange([
				Vector3.Back, new Vector3(arrowSpread, -arrowSpread, 0.9f),
				Vector3.Back, new Vector3(-arrowSpread, arrowSpread, 0.9f),
			]);

			float offset = 0.05f;
			foreach (int i in Enumerable.Range(0, lines.Count))
			{
				Vector3 point = lines[i];
				lines.Add(new Vector3(point.X + offset, point.Y + offset, point.Z));
			}
		}

		if (!_isInitialized)
		{
			Initialize();
		}

		gizmo.AddLines([.. lines], GetMaterial(Plugin.GizmoForwardColor, gizmo));

		base._Redraw(gizmo);
	}
}
#endif