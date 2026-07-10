using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using Godot;
using Godot.Collections;
namespace Portals3D;

/// <summary>
/// <para>
/// To get started, create two Portal3D instances and set their <see cref="ExitPortal"/> to each other.
/// </para>
/// <para>
/// This creates a linked portal pair that you can look through. Make your player to collide with
/// <see cref="TeleportCollisionMask"/> and you will be able to walk back and forth through the portal.
/// </para>
/// <para>
/// To integrate portals into your game, you can make use of the <b>Signals</b> <see cref="OnTeleport"/> and <see cref="OnTeleportReceive"/> during gameplay.
/// </para>
/// <para>
/// The next level is to make use of the portal's callbacks, mainly <see cref="OnTeleportCallback"/>.
/// </para>
/// <para>
/// If you need to raycast through a portal checkout the <see cref="ForwardRaycast"/> and <see cref="ForwardRaycastQuery"/> methods.
/// </para>
/// <para>
/// For optimization, use the <see cref="Activate"/> and <see cref="Deactivate"/> methods to control which portals are consuming resources.
/// </para>
/// <para>
/// <em><b>TIP:</b> For easy defaults management of various portals, create a scene with Portal3D and the root and re-use that scene instead.</em>
/// </para>
/// </summary>
[Tool, Icon("uid://d22d43uoy7fnv"), GlobalClass]
public partial class Portal3D : Node3D
{
	#region Public API

	/// <summary>
	/// Emitted when this portal teleports something. Also see the signal <see cref="OnTeleportReceive"/>.
	/// </summary>
	/// <param name="node">The teleported node.</param>
	[Signal] public delegate void OnTeleportEventHandler(Node3D node);

	/// <summary>
	/// Emitted when this portal receives a teleport. Also see the signal <see cref="OnTeleport"/>.
	/// </summary>
	/// <param name="node">The teleported node.</param>
	[Signal] public delegate void OnTeleportReceiveEventHandler(Node3D node);


	/// <summary>
	/// Activates the portal and recreates internal viewports if needed.
	/// </summary>
	public void Activate()
	{
		ProcessMode = Node.ProcessModeEnum.Inherit;
		IsActive = true;

		if (PortalViewport == null)
		{
			SetupCameras();
		}

		Show();
	}


	/// <summary>
	/// Disables all processing and hides the portal. Optionally destroys the viewports, freeing memory.
	/// </summary>
	/// <param name="destroyViewports">Optionally destroy the viewports to free memory.</param>
	public void Deactivate(bool destroyViewports = false)
	{
		Hide();

		WatchlistTeleportables.Clear();

		if (destroyViewports)
		{
			if (PortalViewport != null)
			{
				PortalViewport.QueueFree();
				PortalViewport = null;
				PortalCamera = null;
			}
		}

		IsActive = false;
		ProcessMode = Node.ProcessModeEnum.Disabled;
	}


	/// <summary>
	/// <para>
	/// Helper method for checking for raycast collisions through portals. 
	/// Implement a method that checks your <c>RayCast3D</c> collisions and 
	/// if it hits a portals <c>Area3D</c> then forward the ray through the portal:
	/// </para>
	/// <c>RaycastColliderParent.ForwardRaycast(YourRayCast3D). . .</c>
	/// </summary>
	/// <param name="rayCast">The raycast to forward.</param>
	/// <returns>A dictionary of the raycast parameters or an empty dictionary if nothings was intersected.</returns>
	public Dictionary ForwardRaycast(RayCast3D rayCast)
	{
		Vector3 start = ToExitPosition(rayCast.GetCollisionPoint());
		Vector3 goal = ToExitPosition(rayCast.ToGlobal(rayCast.TargetPosition));

		PhysicsRayQueryParameters3D query = PhysicsRayQueryParameters3D.Create
		(
			start,
			goal,
			rayCast.CollisionMask,
			[this.TeleportArea.GetRid(), ExitPortal.TeleportArea.GetRid()]
		);
		query.CollideWithAreas = rayCast.CollideWithAreas;
		query.CollideWithBodies = rayCast.CollideWithBodies;
		query.HitBackFaces = rayCast.HitBackFaces;
		query.HitFromInside = rayCast.HitFromInside;

		return GetWorld3D().DirectSpaceState.IntersectRay(query);
	}


	/// <summary>
	/// When doing raycasts directly with <c>PhysicsDirectSpaceState3D.IntersectRay()</c>, 
	/// implement a method that checks your collisions and if a portal is hit, pass the 
	/// <c>PhysicsRayQueryParameters3D</c> to this method.
	/// 
	/// <para>
	/// If you are using <c>RayCast3D</c> for raycasting see <c>ForwardRaycast()</c>
	/// </para>
	/// </summary>
	/// <param name="parameters">The ray query parameters of your raycast.</param>
	/// <returns>A dictionary of the raycast parameters or an empty dictionary if nothings was intersected.</returns>
	public Dictionary ForwardRaycastQuery(PhysicsRayQueryParameters3D parameters)
	{
		Vector3 start = ToExitPosition(parameters.From);
		Vector3 end = ToExitPosition(parameters.To);
		start = ExitPortal.LineIntersection(start, end);

		Array<Rid> excludes = [this.TeleportArea.GetRid(), ExitPortal.TeleportArea.GetRid()];
		excludes.AddRange(parameters.Exclude);

		PhysicsRayQueryParameters3D query = PhysicsRayQueryParameters3D.Create
		(
			start,
			end,
			parameters.CollisionMask,
			excludes
		);
		query.CollideWithAreas = parameters.CollideWithAreas;
		query.CollideWithBodies = parameters.CollideWithBodies;
		query.HitBackFaces = parameters.HitBackFaces;
		query.HitFromInside = parameters.HitFromInside;

		return GetWorld3D().DirectSpaceState.IntersectRay(query);
	}


	/// <summary>
	/// A method for use in objects that teleport.
	/// This is called on a teleported node if <c>HasMethod()</c> returns true.
	/// <para>
	/// Example:
	/// </para>
	/// <code lang="csharp">
	/// // In a node that uses portals
	/// private void OnTeleport(Portal3D portal)
	/// {
	/// 	// stuff here...
	/// }
	/// </code>
	/// </summary>
	private static readonly StringName OnTeleportCallback = new("OnTeleport");

	/// <summary>
	/// A method for use in objects that teleport with duplicate meshes turned on.
	/// This is called on a teleported node if <c>HasMethod()</c> returns true.
	/// <para>
	/// Example:
	/// </para>
	/// <code lang="csharp">
	/// [Export] MeshInstance3D mesh;
	/// 
	/// private Array&lt;MeshInstance3D&gt; GetTeleportableMeshes()
	/// {
	/// 	// stuff here...
	/// 	return [.. mesh];
	/// }
	/// </code>
	/// </summary>
	private static readonly StringName DuplicateMeshesCallback = new("GetTeleportableMeshes");

	/// <summary>
	/// By default, the object triggering the teleport gets teleported. 
	/// You can override this with a metadata property that contains a <c>NodePath</c>.
	/// If the metadata property is set, the node at the path inputted will be teleported
	/// instead.
	/// <para>
	/// Example:
	/// </para>
	/// <code lang="csharp">
	/// public override void _Ready()
	/// {
	/// 	this.SetMeta(TeleportRootMeta, GetParent().GetPath()); // Parent NodePath
	/// }
	/// </code>
	/// </summary>
	private static readonly StringName TeleportRootMeta = new("TeleportRoot");

	#endregion

	#region Export Members

	private Vector2 _portalSize = new(2.0f, 2.5f);
	/// <summary>
	/// Size of the portal rectangle, height and width.
	/// </summary>
	[Export] public Vector2 PortalSize
	{
		get => _portalSize;
		set
		{
			_portalSize = value;
#if TOOLS
			if (IsCausedByUserInteraction(nameof(PortalSize)) && PortalMesh != null)
			{
				OnPortalSizeChanged();
				UpdateConfigurationWarnings();
				ExitPortal?.UpdateConfigurationWarnings();
			}
#endif
		}
	}

	private Portal3D _exitPortal = null;
	/// <summary>
	/// The exit of <i>this</i> portal. The portal camera renders
	/// what it sees through the exit portal and teleports take you
	/// there.
	/// <para>
	/// This property is <b>REQUIRED</b>, it can never be <c>null</c>.
	/// </para>
	/// This property can be changed during gameplay to switch the destination of
	/// <i>this</i> portal.
	/// <para>
	/// <b>TIP:</b> Commonly, two portals have eachother as their exits, but, you can also
	/// try one-way portals and self-as-exit as well!
	/// </para>
	/// </summary>
	[Export]
	public Portal3D ExitPortal
	{
		get => _exitPortal;
		set
		{
			_exitPortal = value;
			UpdateConfigurationWarnings();
			NotifyPropertyListChanged();
		}
	}

	/// <summary>
	/// Set this to manually override the main camera of the scene.
	/// By default it's inferred as the camera rendering the parent
	/// viewport of the portal.
	/// <para>
	/// You may need to set this if your game uses multiple SubViewports.
	/// </para>
	/// </summary>
	[ExportGroup("Rendering")]	
	[Export] public Camera3D PlayerCamera;

	private float _portalFrameWidth = 0.0f;
	/// <summary>
	/// The portal camera sets its <c>Camera3D.Near</c> as close to the portal
	/// as possible in an effort to clip objects close behind the portal.
	/// <para>
	/// This value offsets the portal camera's near clip plane. This might be usefull
	/// if the portal has a thick frame around it.
	/// </para>
	/// </summary>
	[Export(PropertyHint.Range, "0.0, 10.0, 0.01")]
	public float PortalFrameWidth
	{
		get => _portalFrameWidth;
		set => _portalFrameWidth = value;
	}

	/// <summary>
	/// Options for different sizes of the internal viewports. 
	/// This helps to reduce memory usage by not rendering the
	/// portals at full resolution. Viewports are resized on window resize.
	/// </summary>
	public enum PortalViewportSizeMode
	{
		/// <summary>
		/// Render at full window resolution.
		/// </summary>
		Full,
		/// <summary>
		/// Portal will be at most this wide. Height is calculated from the window aspect ratio.
		/// </summary>
		MaxWidthAbsolute,
		/// <summary>
		/// Portal viewport will be a fraction of the full window size.
		/// </summary>
		Fractional
	}
	private PortalViewportSizeMode _viewportSizeMode = PortalViewportSizeMode.Full;
	/// <summary>
	/// Size mode to use for the portal viewport size. Only set this via the inspector.
	/// </summary>
	[Export] public PortalViewportSizeMode ViewportSizeMode
	{
		get => _viewportSizeMode;
		set
		{
			_viewportSizeMode = value;
			NotifyPropertyListChanged();
		}
	}

	/// <summary>
	/// "this" wide for use in MaxWidthAbsolute setting of portal viewport size mode.
	/// </summary>
	public int ViewportSizeMaxWidthAbsolute = (int)ProjectSettings.GetSetting("display/window/size/viewport_width");
	/// <summary>
	/// The fraction to use for fractionalization of the viewports.
	/// </summary>
	public float ViewportSizeFractional = 0.5f;

	/// <summary>
	/// Options for the direction from which you expect the portal to be viewed.
	/// <para>
	/// Use cases:
	/// </para>
	/// One-way portals, visual-only portals (IsTeleport false), or portals that are flush with a wall.
	/// </summary>
	public enum PortalViewDirection
	{
		/// <summary>
		/// View from either side.
		/// </summary>
		FrontAndBack,
		/// <summary>
		/// View from the portals FORWARD direction only.
		/// </summary>
		OnlyFront,
		/// <summary>
		/// View from the portals BACK direction only.
		/// </summary>
		OnlyBack
	}
	private PortalViewDirection _viewDirection = PortalViewDirection.FrontAndBack;
	/// <summary>
	/// The direction from which you expect the portal to be viewed. 
	/// Restricting this restricts the way the portal mesh is shifted 
	/// around when player looks at the portal from different sides.
	/// <para>
	/// </para>
	/// Restrict this if the portal can be seen from the sides and it
	/// has no portal frame around it to cover the shifting mesh.
	/// </summary>
	[Export] public PortalViewDirection ViewDirection
	{
		get => _viewDirection;
		set => _viewDirection = value;
	}

	private uint _portalRenderLayer = 1 << 19;
	/// <summary>
	/// The portal mesh setting for the visual instance layer(s) so that portal camera don't see other portals.
	/// </summary>
	[Export(PropertyHint.Layers3DRender)] public uint PortalRenderLayer
	{
		get => _portalRenderLayer;
		set
		{
			_portalRenderLayer = value;
			if (IsCausedByUserInteraction(nameof(PortalRenderLayer)) && PortalMesh != null)
			{
				PortalMesh.Layers = value;
			}
		}
	}

	private bool _isTeleport = true;
	/// <summary>
	/// If <b>true</b>, the portal is also a teleport.
	/// <para>
	/// If <b>false</b>, the portal is visual-only.
	/// </para>
	/// This is for use in the editor, for runtime teleport toggling,
	/// see <see cref="Activate"/> and <see cref="Deactivate"/>
	/// </summary>
	[ExportGroup("Teleport")]
	[Export]
	public bool IsTeleport
	{
		get => _isTeleport;
		set
		{
			_isTeleport = value;
#if TOOLS
			if (IsCausedByUserInteraction(nameof(IsTeleport)))
			{
				SetupTeleport();
				NotifyPropertyListChanged();
			}
#endif
		}
	}

	/// <summary>
	/// Options for the direction an object has to enter the portal
	/// to be teleported.
	/// </summary>
	public enum PortalTeleportDirection
	{
		/// <summary>
		/// Teleport from the portals FORWARD direction.
		/// </summary>
		Front,
		/// <summary>
		/// Teleport from the portals BACK direction.
		/// </summary>
		Back,
		/// <summary>
		/// Teleport from the either direction of the portal.
		/// </summary>
		FrontAndBack
	}
	private PortalTeleportDirection _teleportDirection = PortalTeleportDirection.FrontAndBack;
	/// <summary>
	/// Portal will only teleport objects from the direction(s) set.
	/// </summary>
	[Export] public PortalTeleportDirection TeleportDirection
	{
		get => _teleportDirection;
		set => _teleportDirection = value;
	}

	private float _rigidbodyBoost = 0.0f;
	/// <summary>
	/// When a RigidBody3D goes through the portal, 
	/// give its new normalized velocity a little boost.
	/// Makes objects flying out of portals more fun.
	/// <para>
	/// Recommended values of 1 to 3, can go higher.
	/// </para>
	/// </summary>
	[Export(PropertyHint.Range, "0.0, 5.0, 0.01, or_greater")] public float RigidbodyBoost
	{
		get => _rigidbodyBoost;
		set => _rigidbodyBoost = value;
	}

	private float _teleportTolerance = 0.5f;
	/// <summary>
	/// When teleporting, the portal checks if the teleported object 
	/// is less than <b>this</b> near.
	/// <para>
	/// Prevents false negatives when multiple portals are on top of each other.
	/// </para>
	/// </summary>
	[Export(PropertyHint.Range, "0.0, 5.0, 0.01, or_greater")] public float TeleportTolerance
	{
		get => _teleportTolerance;
		set => _teleportTolerance = value;
	}

	/// <summary>
	/// Flags for events that happen when something is teleported.
	/// </summary>
	public enum PortalTeleportInteractions
	{
		/// <summary>
		/// The portal will try to call OnTeleportCallback on the teleported node.
		/// </summary>
		Callback = 1 << 0,
		/// <summary>
		/// When the player is teleported, their X and Z rotations are
		/// tweened to zero. Resets unwanted rotation from going through
		/// a tilted portal. If checked, this happens BEFORE the callback.
		/// </summary>
		PlayerUpright = 1 << 1,
		/// <summary>
		/// Duplicates the meshes present on the teleported object, resulting 
		/// in a <i>smooth teleport</i> from a 3rd person POV.
		/// <para>
		/// To use this feature, implement a method using the DuplicateMeshesCallback.
		/// </para>
		/// Each mesh returned in the meshes callback array needs to implement a special shader material.
		/// <para>
		/// See shaderinclude at <c>addons/portalsCS/materials/portalclip_mesh.gdshaderinc</c>.
		/// </para>
		/// </summary>
		DuplicateMeshes = 1 << 2
	}
	private int _teleportInteractions = (int)PortalTeleportInteractions.Callback | (int)PortalTeleportInteractions.PlayerUpright;
	/// <summary>
	/// See <see cref="PortalTeleportInteractions"/> for options.
	/// </summary>
	[Export(PropertyHint.Flags, "Callback, Player Upright, Duplicate Meshes")] public int TeleportInteractions
	{
		get => _teleportInteractions;
		set => _teleportInteractions = value;
	}

	private int _teleportCollisionMask = 1 << 15;
	/// <summary>
	/// Any collision objects detected by this mask will be registered 
	/// by the portal and teleported when they cross the boundary.
	/// </summary>
	[Export(PropertyHint.Layers3DPhysics)] public int TeleportCollisionMask
	{
		get => _teleportCollisionMask;
		set => _teleportCollisionMask = value;
	}

	private bool _startDeactivated = false;
	/// <summary>
	/// If the portal is not immediately visible on scene start, it can be
	/// started in disabled mode. It will not create the subviewports, saving
	/// memory.
	/// <para>
	/// Deactivated portals are also process disabled.
	/// </para>
	/// To reactivae a portal see <see cref="Activate"/>.
	/// </summary>
	[ExportGroup("Advanced")]
	[Export]
	public bool StartDeactivated
	{
		get => _startDeactivated;
		set => _startDeactivated = value;
	}

	#endregion

	#region Internal

	// TODO: Decide if this should be public or not...
	private bool _isActive = true;
	internal bool IsActive
	{
		get => _isActive;
		set => _isActive = value;
	}

	private float _portalThickness = 0.05f;
	internal float PortalThickness
	{
		get => _portalThickness;
		set
		{
			_portalThickness = value;
#if TOOLS
			if (IsCausedByUserInteraction(nameof(PortalThickness)) && PortalMesh != null)
			{
				OnPortalSizeChanged();
			}
#endif
		}
	}

	private NodePath _portalMeshPath;
	/// <summary>
	/// Mesh used to visualize the portals surface.
	/// Created when the portal is added to the scene
	/// <b>in the editor</b>.
	/// </summary>
	public NodePath PortalMeshPath
	{
		get => _portalMeshPath;
		set => _portalMeshPath = value;
	}
	internal MeshInstance3D PortalMesh
	{
		get
		{
			return PortalMeshPath != null && PortalMeshPath != "" ? GetNode<MeshInstance3D>(PortalMeshPath) : null;
		}
	}

	private NodePath _teleportAreaPath;
	/// <summary>
	/// When a teleportable object comes near the protal, it's registered by this area and watched
	/// every frame to trigger the teleport.
	/// <para>
	/// Created by toggling <see cref="IsTeleport"/> in the editor.
	/// </para>
	/// </summary>
	public NodePath TeleportAreaPath
	{
		get => _teleportAreaPath;
		set => _teleportAreaPath = value;
	}
	internal Area3D TeleportArea
	{
		get
		{
			return TeleportAreaPath != null && TeleportAreaPath != "" ? GetNode<Area3D>(TeleportAreaPath) : null;
		}
	}

	private NodePath _teleportColliderPath;
	/// <summary>
	/// Collider for <see cref="TeleportArea"/>.
	/// <para>
	/// Created by toggling <see cref="IsTeleport"/> in the editor.
	/// </para>
	/// </summary>
	public NodePath TeleportColliderPath
	{
		get => _teleportColliderPath;
		set => _teleportColliderPath = value;
	}
	internal CollisionShape3D TeleportCollider
	{
		get
		{
			return TeleportColliderPath != null && TeleportColliderPath != "" ? GetNode<CollisionShape3D>(TeleportColliderPath) : null;
		}
	}

	/// <summary>
	/// Camera that looks through the <see cref="ExitPortal"/> and renders to <see cref="PortalViewport"/>.
	/// <para>
	/// Created in <see cref="_Ready"/>.
	/// </para>
	/// </summary>
	internal Camera3D PortalCamera = null;

	/// <summary>
	/// Viewport that supplies the albedo texture to portal mesh. 
	/// Redered by <see cref="PortalCamera"/>.
	/// <para>
	/// Created in <see cref="_Ready"/>.
	/// </para>
	/// </summary>
	internal SubViewport PortalViewport = null;

	/// <summary>
	/// Metadata about teleported objects.
	/// When the portal detects a teleportable body (or area) nearby, 
	/// it gathers this metadata and starts watching it every frame
	/// for teleportation.
	/// </summary>
	internal partial class TeleportableMetadata : GodotObject
	{
		/// <summary>
		/// Forward distance from the portal.
		/// </summary>
		public float Forward = 0.0f;
		/// <summary>
		/// True if the player is an ancestor of the teleportable 
		/// or if the teleportable is the player camera.
		/// </summary>
		public bool IsPlayer = false;
		/// <summary>
		/// Meshes that the object gave for duplication.
		/// <para>
		/// See: <see cref="DuplicateMeshesCallback"/>.
		/// </para>
		/// </summary>
		public Array<MeshInstance3D> Meshes = [];
		/// <summary>
		/// Cloned <see cref="TeleportableMetadata.Meshes"/> using <see cref="Node.Duplicate"/>.
		/// </summary>
		public Array<MeshInstance3D> MeshClones = [];
	}

	/// <summary>
	/// List of physics bodies that are being watched by the portal. 
	/// They are registered with their instance IDs as the keys.
	/// <para>
	/// Registering them by their object references becomes unreliable 
	/// when the teleport candiate gets freed.
	/// </para>
	/// </summary>
	internal Godot.Collections.Dictionary<ulong, TeleportableMetadata> WatchlistTeleportables = [];

	/// <summary>
	/// <para>
	/// Stores the status of properties that have been changed from default values.
	/// </para>
	/// <para>
	/// This is per-portal so it protects property setters from overriding
	/// changed values or calling setup methods on build.
	/// </para>
	/// </summary>
	public Godot.Collections.Dictionary<string, bool> PropertyStatusList = [];

	private static readonly Shader PortalShader = GD.Load<Shader>("uid://csiava4euv75d");
	private static readonly StandardMaterial3D EditorPreviewMaterial = GD.Load<StandardMaterial3D>("uid://suwscljyisas");

	#endregion

#if TOOLS
	#region Editor Configuration

	/// <summary>
	/// Connect to editor only signals.
	/// </summary>
	public override void _EnterTree()
	{
		if (Engine.IsEditorHint())
		{
			EditorInspector editorInspector = EditorInterface.Singleton.GetInspector();
			editorInspector.PropertyEdited += OnPropertyEdited;
		}

		base._EnterTree();
	}

	/// <summary>
	/// Disconnect from editor only signals.
	/// </summary>
	public override void _ExitTree()
	{
		if (Engine.IsEditorHint() && IsNodeReady())
		{
			EditorInspector editorInspector = EditorInterface.Singleton.GetInspector();
			editorInspector.PropertyEdited -= OnPropertyEdited;
		}

		base._ExitTree();
	}


	/// <summary>
	/// This is <see cref="_Ready"/> but for the editor only.
	/// </summary>
	private void EditorReady()
	{
		AddToGroup((StringName)PortalSettings.GetSetting("PortalsGroupName"), true);
		SetNotifyTransform(true);

		ProcessPriority = 100;
		ProcessPhysicsPriority = 100;

		SetupMesh();
		SetupTeleport();

		this.GroupNode(this);
	}

	private void Notification(long what)
	{
		switch (what)
		{
			case NotificationTransformChanged:
				UpdateGizmos();
				break;

			default:
				break;
		}
	}

	private void EditorPairPortals()
	{
		Debug.Assert(ExitPortal != null, "My own exit has to be set!");
		ExitPortal.ExitPortal = this;
		NotifyPropertyListChanged();
	}

	private void EditorSyncPortalSizes()
	{
		Debug.Assert(ExitPortal != null, "My own exit has to be set!");
		PortalSize = ExitPortal.PortalSize;
		NotifyPropertyListChanged();
	}

	private void SetupTeleport()
	{
		if (!IsTeleport)
		{
			if (TeleportArea != null)
			{
				TeleportArea.QueueFree();
				TeleportAreaPath = null;
			}
			if (TeleportCollider != null)
			{
				TeleportCollider.QueueFree();
				TeleportColliderPath = null;
			}
			return;
		}

		if (TeleportArea != null && TeleportCollider != null) return;

		Area3D area = new() { Name = nameof(TeleportArea) };

		AddChildInEditor(this, area);
		TeleportAreaPath = GetPathTo(area);

		CollisionShape3D collider = new() { Name = nameof(TeleportCollider) };
		BoxShape3D box = new();
		box.Size = box.Size with { X = PortalSize.X, Y = PortalSize.Y };
		collider.Shape = box;

		AddChildInEditor(TeleportArea, collider);
		TeleportColliderPath = GetPathTo(collider);
	}

	private void OnPortalSizeChanged()
	{
		if (PortalMesh == null)
		{
			GD.PushError("Failed to update portal size, portal has no mesh");
			return;
		}

		PortalBoxMesh pbm = (PortalBoxMesh)PortalMesh.Mesh;
		pbm.Size = new Vector3(PortalSize.X, PortalSize.Y, 1);
		PortalMesh.Scale = PortalMesh.Scale with { Z = PortalThickness };

		if (IsTeleport && TeleportCollider != null)
		{
			BoxShape3D boxShape = (BoxShape3D)TeleportCollider.Shape;
			boxShape.Size = boxShape.Size with { X = PortalSize.X, Y = PortalSize.Y };
		}
	}
	#endregion
#endif

	#region Gameplay Logic

	/// <summary>
	/// See: <see cref="EditorReady"/> for editor tool.
	/// <para>Anything below the deferred call is in game logic.</para>
	/// </summary>
	public override void _Ready()
	{
		if (Engine.IsEditorHint())
		{
			CallDeferred("EditorReady");
			return;
		}

		if (PlayerCamera == null)
		{
			PlayerCamera = GetViewport().GetCamera3D();
			Debug.Assert(PlayerCamera != null, "Player camera is missing!");
		}

		ShaderMaterial material = new() { Shader = PortalShader };
		PortalMesh.MaterialOverride = material;

		if (!StartDeactivated)
		{
			SetupCameras();
		}
		else
		{
			CallDeferred("Deactivate", true);
		}

		if (IsTeleport)
		{
			TeleportArea.AreaEntered += OnTeleportAreaEntered;
			TeleportArea.AreaExited += OnTeleportAreaExited;
			TeleportArea.BodyEntered += OnTeleportBodyEntered;
			TeleportArea.BodyExited += OnTeleportBodyExited;
			TeleportArea.CollisionMask = (uint)TeleportCollisionMask;
		}
	}

	/// <summary>
	/// See: <see cref="ProcessCameras"/>, <see cref="ProcessTeleports"/>
	/// </summary>
	/// <param name="delta"></param>
	public override void _Process(double delta)
	{
		if (Engine.IsEditorHint()) return;

		if (IsTeleport) ProcessTeleports();

		ProcessCameras();
	}

	private void ProcessCameras()
	{
		if (PortalCamera == null)
		{
			GD.PushError($"{Name}: No portal camera");
			return;
		}
		if (PlayerCamera == null)
		{
			GD.PushError($"{Name}: No player camera");
			return;
		}
		if (ExitPortal == null)
		{
			GD.PushError($"{Name}: No exit portal");
			return;
		}

		PortalCamera.GlobalTransform = this.ToExitTransform(PlayerCamera.GlobalTransform);
		PortalCamera.Near = CalculateNearPlane();
		PortalCamera.Fov = PlayerCamera.Fov;

		Vector2I pvSize = PortalViewport.Size;
		double degrees = PlayerCamera.Fov * 0.5;
		double halfHeight = PlayerCamera.Near * Math.Tan(degrees * (Math.PI / 180.0));
		double halfWidth = halfHeight * pvSize.X / pvSize.Y;
		float nearDiagonal = new Vector3((float)halfWidth, (float)halfHeight, PlayerCamera.Near).Length();
		PortalMesh.Scale = PortalMesh.Scale with { Z = nearDiagonal };

		bool playerInFrontOfPortal = ForwardDistance(PlayerCamera) > 0;
		float portalShift = 0.0f;
		switch (ViewDirection)
		{
			case PortalViewDirection.OnlyFront:
				portalShift = 1.0f;
				break;

			case PortalViewDirection.OnlyBack:
				portalShift = -1.0f;
				break;

			case PortalViewDirection.FrontAndBack:
				if (playerInFrontOfPortal) portalShift = 1.0f; else portalShift = -1.0f;
				break;
		}

		Vector3 newScale = PortalMesh.Scale;
		newScale.Z *= Math.Sign(portalShift);
		PortalMesh.Scale = newScale;
	}

	private void ProcessTeleports()
	{
		foreach (ulong bodyId in WatchlistTeleportables.Keys)
		{
			if (!IsInstanceIdValid(bodyId))
			{
				EraseTpMetadata(bodyId);
				continue;
			}

			TeleportableMetadata tpMetadata = WatchlistTeleportables[bodyId];
			Node3D body = (Node3D)InstanceFromId(bodyId);
			float lastFwAngle = tpMetadata.Forward;
			float currentFwAngle = ForwardDistance(body);

			bool shouldTeleport = false;
			switch (TeleportDirection)
			{
				case PortalTeleportDirection.Front:
					shouldTeleport = lastFwAngle > 0 && currentFwAngle <= 0;
					break;

				case PortalTeleportDirection.Back:
					shouldTeleport = lastFwAngle < 0 && currentFwAngle >= 0;
					break;

				case PortalTeleportDirection.FrontAndBack:
					shouldTeleport = Math.Sign(lastFwAngle) != Math.Sign(currentFwAngle);
					break;

				default:
					Debug.Assert(false, "This switch should be exhaustive.");
					break;
			}

			if (shouldTeleport && Math.Abs(currentFwAngle) < TeleportTolerance && ExitPortal.IsActive)
			{
				Variant teleportablePath = body.GetMeta(TeleportRootMeta, ".");
				Node3D teleportable = (Node3D)body.GetNode((string)teleportablePath);
				teleportable.GlobalTransform = ToExitTransform(teleportable.GlobalTransform);

				if (teleportable is RigidBody3D rigidTeleportable)
				{
					rigidTeleportable.LinearVelocity = ToExitDirection(rigidTeleportable.LinearVelocity);
					rigidTeleportable.ApplyCentralImpulse(rigidTeleportable.LinearVelocity.Normalized() * RigidbodyBoost);
				}

				EmitSignal(SignalName.OnTeleport, teleportable);
				ExitPortal.EmitSignal(SignalName.OnTeleportReceive, teleportable);

				if (tpMetadata.IsPlayer)
				{
					ProcessCameras();
					ExitPortal.ProcessCameras();
				}

				if (tpMetadata.IsPlayer && CheckTpInteraction((int)PortalTeleportInteractions.PlayerUpright))
				{
					GetTree().CreateTween().TweenProperty(teleportable, "rotation:x", 0, 0.3);
					GetTree().CreateTween().TweenProperty(teleportable, "rotation:z", 0, 0.3);
				}

				if (CheckTpInteraction((int)PortalTeleportInteractions.Callback))
				{
					if (teleportable.HasMethod(OnTeleportCallback)) teleportable.Call(OnTeleportCallback, this);
				}

				TransferTpMetadataToExit(body);
			}
			else
			{
				tpMetadata.Forward = currentFwAngle;
				UpdateTpCloneTransforms(tpMetadata, this);
			}
		}
	}
	
	private float CalculateNearPlane()
	{
		Aabb aabb = new
		(
			new Vector3(-ExitPortal.PortalSize.X / 2, -ExitPortal.PortalSize.Y / 2, 0),
			new Vector3(ExitPortal.PortalSize.X, ExitPortal.PortalSize.Y, 0)
		);

		Vector3 pos = aabb.Position;
		Vector3 size = aabb.Size;

		Vector3 corner1 = ExitPortal.ToGlobal(new Vector3(pos.X, pos.Y, 0));
		Vector3 corner2 = ExitPortal.ToGlobal(new Vector3(pos.X + size.X, pos.Y, 0));
		Vector3 corner3 = ExitPortal.ToGlobal(new Vector3(pos.X + size.X, pos.Y + size.Y, 0));
		Vector3 corner4 = ExitPortal.ToGlobal(new Vector3(pos.X, pos.Y + size.Y, 0));

		Vector3 cameraForward = -PortalCamera.GlobalTransform.Basis.Z.Normalized();

		float d1 = (corner1 - PortalCamera.GlobalPosition).Dot(cameraForward);
		float d2 = (corner2 - PortalCamera.GlobalPosition).Dot(cameraForward);
		float d3 = (corner3 - PortalCamera.GlobalPosition).Dot(cameraForward);
		float d4 = (corner4 - PortalCamera.GlobalPosition).Dot(cameraForward);

		return Math.Max(0.01f, (float)new[] { d1, d2, d3, d4 }.Min() - ExitPortal.PortalFrameWidth);
	}

	private void SetupMesh()
	{
		if (PortalMesh != null) return;

		MeshInstance3D meshInstance = new()
		{
			Name = this.Name + "_Mesh",
			CastShadow = GeometryInstance3D.ShadowCastingSetting.Off,
			Layers = PortalRenderLayer
		};

		PortalBoxMesh boxMesh = new()
		{
			Size = new Vector3(PortalSize.X, PortalSize.Y, 1)
		};

		meshInstance.Mesh = boxMesh;
		meshInstance.Scale = meshInstance.Scale with { Z = PortalThickness };

		meshInstance.MaterialOverride = EditorPreviewMaterial;

		AddChildInEditor(this, meshInstance);
		PortalMeshPath = GetPathTo(meshInstance);
	}

	private void SetupCameras()
	{
		Debug.Assert(!Engine.IsEditorHint(), "This should never run in editor.");
		Debug.Assert(PortalCamera == null);
		Debug.Assert(PortalViewport == null);

		if (ExitPortal == null)
		{
			GD.PushError($"{Name} has no exit portal, failed to setup cameras.");
			return;
		}

		PortalViewport = new SubViewport
		{
			Name = this.Name + "_SubViewport",
			Size = CalculateViewportSize()
		};
		AddChild(PortalViewport, true);

		Godot.Environment adjustedEnv = null;
		if (PlayerCamera.Environment != null)
		{
			adjustedEnv = (Godot.Environment)PlayerCamera.Environment.Duplicate();
		}
		else
		{
			adjustedEnv = (Godot.Environment)PlayerCamera.GetWorld3D().Environment.Duplicate();
		}

		adjustedEnv.TonemapMode = Godot.Environment.ToneMapper.Linear;
		adjustedEnv.TonemapExposure = 1;

		PortalCamera = new Camera3D
		{
			Name = this.Name + "_Camera3D",
			Environment = adjustedEnv
		};

		PortalCamera.CullMask ^= PortalRenderLayer;

		PortalViewport.AddChild(PortalCamera, true);
		PortalCamera.GlobalPosition = ExitPortal.GlobalPosition;

		ShaderMaterial material = (ShaderMaterial)PortalMesh.MaterialOverride;
		material.SetShaderParameter("albedo", PortalViewport.GetTexture());

		Viewport vp = GetViewport();
		if (!vp.IsConnected(Viewport.SignalName.SizeChanged, Callable.From(OnWindowResize)))
		{
			vp.SizeChanged += OnWindowResize;
		}
		else
		{
			GD.PushError($"{Name} failed to connect to OnWindowResize signal.");
		}
	}

	#endregion

	#region Event Handlers

	private void OnTeleportAreaEntered(Area3D area)
	{
		if (WatchlistTeleportables.ContainsKey(area.GetInstanceId())) return;

		ConstructTpMetadata(area);
	}

	private void OnTeleportBodyEntered(Node3D body)
	{
		if (WatchlistTeleportables.ContainsKey(body.GetInstanceId())) return;

		ConstructTpMetadata(body);
	}

	private void OnTeleportAreaExited(Area3D area)
	{
		EraseTpMetadata(area.GetInstanceId());
	}

	private void OnTeleportBodyExited(Node3D body)
	{
		EraseTpMetadata(body.GetInstanceId());
	}

	private void OnWindowResize()
	{
		if (PortalViewport != null) PortalViewport.Size = CalculateViewportSize();
	}

	#endregion

	#region UTILS

	private void ConstructTpMetadata(Node3D node)
	{
		Node teleportable = node.GetNode((NodePath)node.GetMeta(TeleportRootMeta, "."));

		TeleportableMetadata metadata = new()
		{
			Forward = ForwardDistance(node),
			IsPlayer = (teleportable == PlayerCamera) || teleportable.IsAncestorOf(PlayerCamera)
		};

		if (metadata.IsPlayer) SetPortalPairUpdateMode(SubViewport.UpdateMode.Always);

		if (CheckTpInteraction((int)PortalTeleportInteractions.DuplicateMeshes)
		&& teleportable.HasMethod(DuplicateMeshesCallback))
		{
			metadata.Meshes = (Array<MeshInstance3D>)teleportable.Call(DuplicateMeshesCallback);
			foreach (MeshInstance3D mesh in metadata.Meshes)
			{
				MeshInstance3D dupeMesh = (MeshInstance3D)mesh.Duplicate(0);
				dupeMesh.Name = mesh.Name + "_Clone";
				metadata.MeshClones.Add(dupeMesh);
				AddChild(dupeMesh, true);

				Skeleton3D skeleton = mesh.GetNodeOrNull<Skeleton3D>(mesh.Skeleton);
				if (skeleton != null) dupeMesh.Skeleton = dupeMesh.GetPathTo(skeleton);
			}
			EnableMeshClipping(metadata, this);
		}
		WatchlistTeleportables.TryAdd(node.GetInstanceId(), metadata);
	}

	private void EraseTpMetadata(ulong nodeId)
	{
		WatchlistTeleportables.TryGetValue(nodeId, out TeleportableMetadata metadata);
		if (metadata != null)
		{
			if (metadata.IsPlayer) SetPortalPairUpdateMode(SubViewport.UpdateMode.WhenVisible);

			foreach (MeshInstance3D mesh in metadata.Meshes) DisableMeshClipping(mesh);
			foreach (MeshInstance3D meshClone in metadata.MeshClones) meshClone.QueueFree();
		}
		if (!WatchlistTeleportables.Remove(nodeId)) return;
	}

	private void TransferTpMetadataToExit(Node3D body)
	{
		ulong bodyId = body.GetInstanceId();
		TeleportableMetadata metadata = WatchlistTeleportables[bodyId];
		Debug.Assert(metadata != null, "Attempted to transfer teleport metadata for a node that is not being watched.");

		// Self-teleport edge case to keep metadata and refresh clipping.
		if (ExitPortal == this)
		{
			metadata.Forward = ForwardDistance(body);
			EnableMeshClipping(metadata, this);
			UpdateTpCloneTransforms(metadata, this);
			return;
		}

		if (!ExitPortal.IsTeleport) return; // If one way teleport.

		metadata.Forward = ExitPortal.ForwardDistance(body);
		EnableMeshClipping(metadata, ExitPortal);
		UpdateTpCloneTransforms(metadata, ExitPortal);

		ExitPortal.WatchlistTeleportables.TryAdd(bodyId, metadata);

		if (metadata.IsPlayer && ExitPortal.ExitPortal != this)
		{
			PortalViewport.RenderTargetUpdateMode = SubViewport.UpdateMode.WhenVisible;
			ExitPortal.SetPortalPairUpdateMode(SubViewport.UpdateMode.Always);
		}
		WatchlistTeleportables.Remove(bodyId);
	}
	
	private void UpdateTpCloneTransforms(TeleportableMetadata metadata, Portal3D portal)
	{
		for (int i = 0; i < metadata.MeshClones.Count; i++)
		{
			MeshInstance3D mesh = metadata.Meshes[i];
			MeshInstance3D clone = metadata.MeshClones[i];
			clone.GlobalTransform = portal.ToExitTransform(mesh.GlobalTransform);
		}
	}

	private void EnableMeshClipping(TeleportableMetadata metadata, Portal3D alongPortal)
	{
		foreach (MeshInstance3D meshInstance in metadata.Meshes)
		{
			Vector3 clipNormal = Math.Sign(metadata.Forward) * alongPortal.GlobalBasis.Z;
			meshInstance.SetInstanceShaderParameter("portal_clip_active", true);
			meshInstance.SetInstanceShaderParameter("portal_clip_point", alongPortal.GlobalPosition);
			meshInstance.SetInstanceShaderParameter("portal_clip_normal", clipNormal);
		}

		Portal3D exitPortal = alongPortal.ExitPortal;
		foreach (MeshInstance3D meshClone in metadata.MeshClones)
		{
			Vector3 clipNormal = Math.Sign(metadata.Forward) * exitPortal.GlobalBasis.Z;
			meshClone.SetInstanceShaderParameter("portal_clip_active", true);
			meshClone.SetInstanceShaderParameter("portal_clip_point", exitPortal.GlobalPosition);
			meshClone.SetInstanceShaderParameter("portal_clip_normal", clipNormal);
		}
	}

	private void DisableMeshClipping(MeshInstance3D meshInstance)
	{
		meshInstance.SetInstanceShaderParameter("portal_clip_active", false);
	}

	private Transform3D ToExitTransform(Transform3D gTransform)
	{
		Transform3D relativeToPortal = GlobalTransform.AffineInverse() * gTransform;
		Transform3D flippedTransform = relativeToPortal.Rotated(Vector3.Up, (float)Math.PI);
		Transform3D relativeToTarget = ExitPortal.GlobalTransform * flippedTransform;
		return relativeToTarget;
	}

	private Vector3 ToExitDirection(Vector3 real)
	{
		Vector3 relativeToPortal = GlobalBasis.Inverse() * real;
		Vector3 flippedVector = relativeToPortal.Rotated(Vector3.Up, (float)Math.PI);
		Vector3 relativeToTarget = ExitPortal.GlobalBasis * flippedVector;
		return relativeToTarget;
	}

	private Vector3 ToExitPosition(Vector3 gPos)
	{
		Vector3 localVector = GlobalTransform.AffineInverse() * gPos;
		Vector3 rotatedVector = localVector.Rotated(Vector3.Up, (float)Math.PI);
		Vector3 localAtExit = ExitPortal.GlobalTransform * rotatedVector;
		return localAtExit;
	}

	private float ForwardDistance(Node3D node)
	{
		Vector3 portalFront = this.GlobalTransform.Basis.Z.Normalized();
		Vector3 nodeRelative = node.GlobalTransform.Origin - this.GlobalTransform.Origin;
		return portalFront.Dot(nodeRelative);
	}

	private void AddChildInEditor(Node parent, Node node)
	{
		parent.AddChild(node, true);
		if (this.Owner == null)
		{
			node.Owner = this;
		}
		else
		{
			node.Owner = this.Owner;
		}
	}

	private void OnPropertyEdited(string property)
	{
		bool newProperty = PropertyStatusList.TryAdd(property, true);
		if (!newProperty) PropertyStatusList[property] = true;
	}
	
	private bool CheckPropertyEditedStatus(string property)
	{
		PropertyStatusList.TryGetValue(property, out bool value);
		return value;
	}

	private bool IsCausedByUserInteraction(string property)
	{
		return Engine.IsEditorHint() && IsNodeReady() && CheckPropertyEditedStatus(property);
	}

	private void GroupNode(Node node)
	{
		node.SetMeta("_edit_group_", true);
	}

	private Vector2I CalculateViewportSize()
	{
		Vector2I viewportSize = (Vector2I)GetViewport().GetVisibleRect().Size;
		float aspectRatio = viewportSize.X / viewportSize.Y;

		switch (ViewportSizeMode)
		{
			case PortalViewportSizeMode.Full:
				return viewportSize;

			case PortalViewportSizeMode.MaxWidthAbsolute:
				int width = Math.Min(ViewportSizeMaxWidthAbsolute, viewportSize.X);
				return new Vector2I(width, (int)(width / aspectRatio));

			case PortalViewportSizeMode.Fractional:
				Vector2 calculateFractional = (Vector2)viewportSize * ViewportSizeFractional;
				return (Vector2I)calculateFractional;
		}

		GD.PushError("Failed to determine desired viewport size.");
		return new Vector2I
		(
			(int)ProjectSettings.GetSetting("display/window/size/viewport_width"),
			(int)ProjectSettings.GetSetting("display/window/size/viewport_height")
		);
	}

	private bool CheckTpInteraction(int flag)
	{
		return (TeleportInteractions & flag) > 0;
	}

	private void SetPortalPairUpdateMode(SubViewport.UpdateMode mode)
	{
		Debug.Assert(IsInstanceIdValid(ExitPortal.GetInstanceId()));
		this.PortalViewport.RenderTargetUpdateMode = mode;
		if (ExitPortal.PortalViewport != null) ExitPortal.PortalViewport.RenderTargetUpdateMode = mode;
	}

	private Vector3 LineIntersection(Vector3 start, Vector3 end)
	{
		Vector3 planeNormal = -GlobalBasis.Z;
		Vector3 planePoint = GlobalPosition;

		Vector3 lineDir = end - start;
		float denom = planeNormal.Dot(lineDir);

		if (Math.Abs(denom) < 1e-6) return Vector3.Zero;

		float t = planeNormal.Dot(planePoint - start) / denom;
		return start + lineDir * t;
	}

	#endregion

#if TOOLS
	#region Godot Editor Integrations

	/// <summary>
	/// Custom configuration warnings.
	/// </summary>
	/// <exclude />
	public override string[] _GetConfigurationWarnings()
	{
		List<string> warnings = [];

		Vector3 globalScale = GlobalBasis.Scale;
		if (!globalScale.IsEqualApprox(Vector3.One))
		{
			warnings.Add
			(
				$"Portals should NOT be scaled. Global portal scale is {globalScale}, " +
				$"but should be {Vector3.One}. Make sure the portal and any of the " +
				"portals parents aren't scaled. "
			);
		}

		if (ExitPortal == null)
		{
			warnings.Add("Exit portal is null. ");
		}

		if (ExitPortal != null && !PortalSize.IsEqualApprox(ExitPortal.PortalSize))
		{
			warnings.Add
			(
				"Portal size should be the same as the exit portals size. " +
				$"Portal size: {PortalSize} Shoulde be: {ExitPortal.PortalSize}"
			);
		}

		// TODO: Is this needed?
		base._GetConfigurationWarnings();

		return [.. warnings];
	}

	/// <summary>
	/// Overridden for custom export properties.
	/// </summary>
	/// <exclude />
	public override Array<Dictionary> _GetPropertyList()
	{
		Array<Dictionary> config = [];

		config.Add(new Dictionary()
		{
			{"name", nameof(PortalThickness)},
			{"type", (int)Variant.Type.Float},
			{"usage", (int)PropertyUsageFlags.Storage}
		});
		config.Add(new Dictionary()
		{
			{"name", nameof(PortalMeshPath)},
			{"type", (int)Variant.Type.NodePath},
			{"usage", (int)PropertyUsageFlags.Storage}
		});
		config.Add(new Dictionary()
		{
			{"name", nameof(TeleportAreaPath)},
			{"type", (int)Variant.Type.NodePath},
			{"usage", (int)PropertyUsageFlags.Storage}
		});
		config.Add(new Dictionary()
		{
			{"name", nameof(TeleportColliderPath)},
			{"type", (int)Variant.Type.NodePath},
			{"usage", (int)PropertyUsageFlags.Storage}
		});
		config.Add(new Dictionary()
		{
			{"name", nameof(PropertyStatusList)},
			{"type", (int)Variant.Type.Dictionary},
			{"usage", (int)PropertyUsageFlags.Storage}
		});

		base._GetPropertyList();

		return config;
	}

	#endregion
#endif
}
