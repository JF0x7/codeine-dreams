#if TOOLS
using Godot.Collections;
using Godot;
namespace Portals3D;

[Tool]
public partial class Plugin : EditorPlugin
{
	internal const string PortalsGroupName = "PortalsGroupName";
	internal const string GizmoExitOutlineActive = "GizmoExitOutlineActive";
	internal const string GizmoExitOutlineColor = "GizmoExitOutlineColor";
	internal const string GizmoForwardActive = "GizmoForwardActive";
	internal const string GizmoForwardColor = "GizmoForwardColor";

	internal static readonly Dictionary<string, Variant> PortalSettingsList = new()
	{
		{ PortalsGroupName, "Portals" },
		{ GizmoExitOutlineActive, true },
		{ GizmoExitOutlineColor, Colors.BlueViolet },
		{ GizmoForwardActive, true },
		{ GizmoForwardColor, Colors.DeepPink }
	};

	private PortalExitOutline portalExitOutlineGizmo = new();
	private PortalForwardDirection portalForwardDirectionGizmo = new();

	public override void _EnterTree()
	{
		foreach (string key in PortalSettingsList.Keys)
		{
			PortalSettings.InitSetting(key, PortalSettingsList[key], true);
		}

		PortalSettings.AddInfo(AtExport.ExportString(PortalsGroupName));
		PortalSettings.AddInfo(AtExport.ExportBool(GizmoExitOutlineActive));
		PortalSettings.AddInfo(AtExport.ExportColorNoAlpha(GizmoExitOutlineColor));
		PortalSettings.AddInfo(AtExport.ExportBool(GizmoForwardActive));
		PortalSettings.AddInfo(AtExport.ExportColorNoAlpha(GizmoForwardColor));

		if ((bool)PortalSettings.GetSetting(GizmoExitOutlineActive))
		{
			AddNode3DGizmoPlugin(portalExitOutlineGizmo);
		}

		if ((bool)PortalSettings.GetSetting(GizmoForwardActive))
		{
			AddNode3DGizmoPlugin(portalForwardDirectionGizmo);
		}
	}

	public override void _ExitTree()
	{
		if (portalExitOutlineGizmo != null)
		{
			RemoveNode3DGizmoPlugin(portalExitOutlineGizmo);
		}

		if (portalForwardDirectionGizmo != null)
		{
			RemoveNode3DGizmoPlugin(portalForwardDirectionGizmo);
		}
	}
}
#endif
