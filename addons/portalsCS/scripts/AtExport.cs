using System.Diagnostics;
using Godot;
using Godot.Collections;
namespace Portals3D;

public partial class AtExport : GodotObject
{
	static Dictionary BaseExport(string propname, int type)
	{
		return new Dictionary()
		{
			{ "name", propname },
			{ "type", type },
			{ "usage", (int)PropertyUsageFlags.Default | (int)PropertyUsageFlags.ScriptVariable }
		};
	}

	internal static Dictionary ExportButton(string propname, string buttonText, string buttonIcon = "Callable")
	{
		Dictionary result = BaseExport(propname, (int)Godot.Variant.Type.Callable);

		Debug.Assert(!buttonText.Contains(','), "Button text cannot contain a comma.");

		result["hint"] = (int)PropertyHint.ToolButton;
		result["hint_string"] = buttonText + ',' + buttonIcon;

		return result;
	}

	internal static Dictionary ExportBool(string propname, bool groupEnable = false)
	{
		Dictionary result = BaseExport(propname, (int)Godot.Variant.Type.Bool);

		if (groupEnable)
		{
			result["hint"] = (int)PropertyHint.GroupEnable;
		}
		return result;
	}

	internal static Dictionary ExportColorNoAlpha(string propname)
	{
		Dictionary result = BaseExport(propname, (int)Godot.Variant.Type.Color);
		result["hint"] = (int)PropertyHint.ColorNoAlpha;
		return result;
	}

	internal static Dictionary ExportString(string propname)
	{
		return BaseExport(propname, (int)Godot.Variant.Type.String);
	}
}
