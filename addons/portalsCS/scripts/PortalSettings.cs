#if TOOLS
using Godot;
using Godot.Collections;
namespace Portals3D;

[Tool]
public partial class PortalSettings : GodotObject
{
	internal static string QualName(string setting)
	{
		return "addons/portalsCS/" + setting;
	}

	internal static void InitSetting(string setting, Variant defaultValue, bool requiresRestart = false)
	{
		setting = QualName(setting);

		if (!ProjectSettings.HasSetting(setting))
		{
			ProjectSettings.SetSetting(setting, defaultValue);
		}

		ProjectSettings.SetInitialValue(setting, defaultValue);
		ProjectSettings.SetRestartIfChanged(setting, requiresRestart);
		ProjectSettings.SetAsBasic(setting, true);
	}

	internal static void AddInfo(Dictionary config)
	{
		string qualName = QualName((string)config["name"]);

		config["name"] = qualName;

		config.Remove("usage");

		ProjectSettings.AddPropertyInfo(config);
	}

	internal static Variant GetSetting(string setting)
	{
		setting = QualName(setting);
		return ProjectSettings.GetSetting(setting);
	}
}
#endif