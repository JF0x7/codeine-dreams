#if TOOLS
using System.Linq;
using Godot;
namespace Portals3D;

[Tool]
public partial class PortalExitOutline : EditorNode3DGizmoPlugin
{
	private const string GizmoName = "PortalExitOutlineGizmo";
	private bool _isInitialized = false;

	public PortalExitOutline()
	{
		// Initialize material using Initialize() method to prevent lifecycle racing.
	}

	// Prevent lifecycle racing by giving portal settings creation some time to complete.
	private void Initialize()
	{
		Color color = (Color)PortalSettings.GetSetting(Plugin.GizmoExitOutlineColor);
		CreateMaterial(Plugin.GizmoExitOutlineColor, color, false, true, false);

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
		gizmo.Clear();

		Godot.Collections.Array<Node> nodes = EditorInterface.Singleton.GetSelection().GetSelectedNodes();
		if (!nodes.Contains(portal)) return;

		Portal3D exitPortal = portal.ExitPortal;
		if (exitPortal == null) return;

		Vector3 extents = new(exitPortal.PortalSize.X, exitPortal.PortalSize.Y, exitPortal.PortalThickness);
		extents /= 2;

		Godot.Collections.Array<Vector3> lines = [];

		lines.AddRange([
			extents, extents * new Vector3(1, -1, 1),
			extents, extents * new Vector3(-1, 1, 1),
			extents * new Vector3(1, -1, 1), extents * new Vector3(-1, -1, 1),
			extents * new Vector3(-1, 1, 1), extents * new Vector3(-1, -1, 1),

			-extents, -extents * new Vector3(1, -1, 1),
			-extents, -extents * new Vector3(-1, 1, 1),
			-extents * new Vector3(1, -1, 1), -extents * new Vector3(-1, -1, 1),
			-extents * new Vector3(-1, 1, 1), -extents * new Vector3(-1, -1, 1),

			extents * new Vector3(1, 1, 1), extents * new Vector3(1, 1, -1),
			extents * new Vector3(1, -1, 1), extents * new Vector3(1, -1, -1),
			extents * new Vector3(-1, 1, 1), extents * new Vector3(-1, 1, -1),
			extents * new Vector3(-1, -1, 1), extents * new Vector3(-1, -1, -1),
		]);

		foreach (int i in Enumerable.Range(0, lines.Count))
		{
			lines[i] = portal.ToLocal(exitPortal.ToGlobal(lines[i]));
		}

		if (!_isInitialized)
		{
			Initialize();
		}

		gizmo.AddLines([.. lines], GetMaterial(Plugin.GizmoExitOutlineColor, gizmo));

		base._Redraw(gizmo);
	}
}
#endif