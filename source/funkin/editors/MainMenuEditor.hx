package funkin.editors;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.ui.FlxButton;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.tweens.FlxTween;
import flixel.addons.display.FlxBackdrop;
import flixel.addons.ui.FlxInputText;
import haxe.Json;
import openfl.utils.Assets;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

import funkin.options.Options;
import funkin.editors.substates.HELPSubState;
import funkin.editors.substates.ResetSubstate;

using StringTools;

typedef MainMenuJson = {
	var options:Array<OptionDataJson>;
	var background:String;
	var backgroundFlash:String;
	var version:String;
	var backgroundX:Float;
	var backgroundY:Float;
}

typedef OptionDataJson = {
	var name:String;
	var x:Float;
	var y:Float;
	var goesToState:Bool;
	@:optional var idleAnim:String;
	@:optional var selectedAnim:String;
}

typedef MenuEditAction = {
	var index:Int;
	var name:String;
	var x:Float;
	var y:Float;
	var goesToState:Bool;
}

class MainMenuEditor extends MusicBeatState
{
	var bg:FlxSprite;
	var menuJson:MainMenuJson;
	var menuItems:FlxTypedGroup<FlxSprite>;

	var canBackgroundMove:Bool = false;
	var canMenuItemMove:Bool = false;
	var optionShit:Array<String> = [];

	var draggingBg:Bool = false;
	var bgDragOffsetX:Float = 0;
	var bgDragOffsetY:Float = 0;

	var draggingItem:Bool = false;
	var draggedItem:FlxSprite = null;
	var itemDragOffsetX:Float = 0;
	var itemDragOffsetY:Float = 0;

	var undoStack:Array<MenuEditAction> = [];
	var redoStack:Array<MenuEditAction> = [];

	var allowMenuItemMove:FlxButton;
	var resetBack:FlxButton;
	var allowBackgroundMove:FlxButton;
	var saveButton:FlxButton;
	var undoButton:FlxButton;
	var redoButton:FlxButton;

	var editorPanelBG:FlxSprite;
	var checkeredBg:FlxBackdrop;
	var editorBG:FlxSprite;

	var objectCheckBtn:FlxButton;
	public var doesObjectGoToState:Bool = true;

	var autoSaveText:FlxText;
	var autoSaveTimer:FlxTimer;

	// Text Input Controls
	var bgPathInput:FlxInputText;
	var loadBgBtn:FlxButton;

	var btnNameInput:FlxInputText;
	var idleAnimInput:FlxInputText;
	var selectedAnimInput:FlxInputText;
	var addButtonBtn:FlxButton;

	override public function create()
	{
		super.create();

		FlxG.mouse.visible = true;

		var jsonPath:String = Paths.json('states/_override/MainMenuState');
		menuJson = null;

		if (jsonPath != null)
		{
			try
			{
				var content:String = #if sys (FileSystem.exists(jsonPath) ? File.getContent(jsonPath) : Assets.getText(jsonPath)) #else Assets.getText(jsonPath) #end;
				menuJson = Json.parse(content);
			}
			catch (e:Dynamic)
			{
				trace("Could not parse JSON at " + jsonPath + ": " + e);
			}
		}

		if (menuJson == null)
		{
			menuJson = {
				options: [],
				background: 'menuBG',
				backgroundFlash: 'menuBGDesat',
				version: '1.0',
				backgroundX: 0,
				backgroundY: 0
			};
		}

		optionShit = [];
		if (menuJson.options != null)
		{
			for (option in menuJson.options)
			{
				optionShit.push(option.name);
			}
		}

		bg = new FlxSprite(menuJson.backgroundX, menuJson.backgroundY);
		if (menuJson.background != null && menuJson.background != "")
			bg.loadGraphic(Paths.image(menuJson.background));
		bg.antialiasing = Options.antialiasing;
		bg.setGraphicSize(Std.int(bg.width * 1.175));
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);

		var yScroll:Float = 0.25;

		editorBG = new FlxSprite(-150, -150).makeGraphic(FlxG.width + 300, FlxG.height + 300, 0xFF808080);
		editorBG.scrollFactor.set(0, yScroll);
		editorBG.visible = false;
		add(editorBG);

		var tileSize:Int = 80;
		var tempSprite:FlxSprite = new FlxSprite().makeGraphic(tileSize * 2, tileSize * 2, FlxColor.TRANSPARENT);
		tempSprite.pixels.fillRect(new openfl.geom.Rectangle(0, 0, tileSize, tileSize), FlxColor.WHITE);
		tempSprite.pixels.fillRect(new openfl.geom.Rectangle(tileSize, tileSize, tileSize, tileSize), FlxColor.WHITE);

		checkeredBg = new FlxBackdrop(tempSprite.graphic, XY, 0, 0);
		checkeredBg.scrollFactor.set(0, yScroll);
		checkeredBg.velocity.set(45, 45);
		checkeredBg.alpha = FlxG.random.float(0.06, 0.12);
		checkeredBg.visible = false;
		add(checkeredBg);

		// Editor Panel Container
		editorPanelBG = new FlxSprite(10, 10).makeGraphic(530, 260, FlxColor.BLACK);
		editorPanelBG.alpha = 0.6;
		editorPanelBG.scrollFactor.set();
		add(editorPanelBG);

		menuItems = new FlxTypedGroup<FlxSprite>();
		add(menuItems);

		rebuildMenuItems();

		// Action Buttons
		allowBackgroundMove = new FlxButton(15, 20, "BG Move", function() {
			canBackgroundMove = !canBackgroundMove;
			canMenuItemMove = false;
			if (!canBackgroundMove) draggingBg = false;
		});

		allowMenuItemMove = new FlxButton(120, 20, "Item Move", function() {
			canMenuItemMove = !canMenuItemMove;
			canBackgroundMove = false;
			if (!canMenuItemMove) {
				draggingItem = false;
				draggedItem = null;
			}
		});

		saveButton = new FlxButton(225, 20, "Save", function() { saveJson(); });
		undoButton = new FlxButton(330, 20, "Undo", function() { undoAction(); });
		redoButton = new FlxButton(435, 20, "Redo", function() { redoAction(); });

		objectCheckBtn = new FlxButton(15, 60, "State Trans: YES", function() {
			doesObjectGoToState = !doesObjectGoToState;
			objectCheckBtn.text = "State Trans: " + (doesObjectGoToState ? "YES" : "NO");
		});

		resetBack = new FlxButton(225, 60, "Reset All", function() {
			editorBG.visible = true;
			checkeredBg.visible = true;
			openSubState(new ResetSubstate(this));
		});

		// Dynamic Background Loader Controls
		bgPathInput = new FlxInputText(15, 100, 150, menuJson.background != null ? menuJson.background : "menuBG", 14);
		loadBgBtn = new FlxButton(175, 100, "Load BG", function() {
			if (bgPathInput.text != null && bgPathInput.text.trim() != "") {
				var newBgKey:String = bgPathInput.text.trim();
				bg.loadGraphic(Paths.image(newBgKey));
				menuJson.background = newBgKey;
				bg.setGraphicSize(Std.int(bg.width * 1.175));
				bg.updateHitbox();
			}
		});

		// Button Creator Controls
		btnNameInput = new FlxInputText(15, 150, 120, "button_name", 14);
		idleAnimInput = new FlxInputText(145, 150, 120, "idle prefix", 14);
		selectedAnimInput = new FlxInputText(275, 150, 120, "selected prefix", 14);

		addButtonBtn = new FlxButton(405, 150, "Add Button", function() {
			addNewButton();
		});

		add(allowBackgroundMove);
		add(allowMenuItemMove);
		add(saveButton);
		add(undoButton);
		add(redoButton);
		add(objectCheckBtn);
		add(resetBack);
		add(bgPathInput);
		add(loadBgBtn);
		add(btnNameInput);
		add(idleAnimInput);
		add(selectedAnimInput);
		add(addButtonBtn);

		autoSaveText = new FlxText(0, 0, 0, "Autosave!", 22);
		autoSaveText.setFormat(Paths.font("vcr.ttf"), 22, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		autoSaveText.x = FlxG.width - autoSaveText.width - 25;
		autoSaveText.y = FlxG.height - autoSaveText.height - 25;
		autoSaveText.alpha = 0;
		autoSaveText.scrollFactor.set();
		add(autoSaveText);

		autoSaveTimer = new FlxTimer().start(60, function(tmr:FlxTimer) {
			triggerAutoSave();
		}, 0);
	}

	function addNewButton()
	{
		var name:String = btnNameInput.text.trim();
		if (name == "" || name == "button_name") return;

		var idle:String = idleAnimInput.text.trim();
		if (idle == "" || idle == "idle prefix") idle = name + " basic";

		var selected:String = selectedAnimInput.text.trim();
		if (selected == "" || selected == "selected prefix") selected = name + " white";

		var newOpt:OptionDataJson = {
			name: name,
			x: 100,
			y: 100 + (menuJson.options.length * 80),
			goesToState: doesObjectGoToState,
			idleAnim: idle,
			selectedAnim: selected
		};

		menuJson.options.push(newOpt);
		optionShit.push(name);
		rebuildMenuItems();
	}

	function rebuildMenuItems()
	{
		menuItems.clear();
		for (i in 0...optionShit.length)
		{
			var optData = menuJson.options[i];
			var menuItem = new FlxSprite(optData.x, optData.y);

			menuItem.antialiasing = Options.antialiasing;
			menuItem.frames = Paths.getSparrowAtlas('mainmenu/menu_' + optionShit[i]);

			var idlePrefix:String = (optData.idleAnim != null && optData.idleAnim != "") ? optData.idleAnim : optionShit[i] + " basic";
			var selectedPrefix:String = (optData.selectedAnim != null && optData.selectedAnim != "") ? optData.selectedAnim : optionShit[i] + " white";

			menuItem.animation.addByPrefix('idle', idlePrefix, 24);
			menuItem.animation.addByPrefix('selected', selectedPrefix, 24);
			menuItem.animation.play('idle');

			var scroll:Float = (optionShit.length - 4) * 0.135;
			if (optionShit.length < 6) scroll = 0;

			menuItem.scrollFactor.set(0, scroll);
			menuItem.updateHitbox();
			menuItems.add(menuItem);
		}
	}

	public function deleteAllContent()
	{
		if (menuItems != null) menuItems.clear();
		if (menuJson != null) menuJson.options = [];

		optionShit = [];
		undoStack = [];
		redoStack = [];

		rebuildMenuItems();
		triggerAutoSave();
	}

	public function triggerAutoSave()
	{
		saveJson();
		if (autoSaveText != null)
		{
			autoSaveText.alpha = 0;
			FlxTween.tween(autoSaveText, {alpha: 1}, 0.4, {
				onComplete: function(twn:FlxTween) {
					FlxTween.tween(autoSaveText, {alpha: 0}, 0.4, {startDelay: 1.2});
				}
			});
		}
	}

	public function saveJson()
	{
		#if sys
		var saveFolder:String = Sys.getCwd() + "assets/data/states/_override";
		if (!FileSystem.exists(saveFolder))
			FileSystem.createDirectory(saveFolder);
		File.saveContent(
			saveFolder + "/MainMenuState.json",
			Json.stringify(menuJson, null, "\t")
		);
		Logs.trace("Saved JSON files to: " + saveFolder);
		#end
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);

		handleBackgroundDragging();
		handleMenuItemDragging();
		handleMenuItemRemoval();
		handleUndoRedoShortcuts();

		if (FlxG.keys.justPressed.ESCAPE)
		{
			FlxG.mouse.visible = false;
			FlxG.switchState(new funkin.editors.EditorPicker());
		}

		if (FlxG.keys.justPressed.F2)
		{
			HELPSubState.helpText = 
				"MAIN MENU EDITOR\n\n" +
				"- Type image key in 'Load BG' field to set background.\n" +
				"- Type button name and custom animation prefixes, then click 'Add Button'.\n" +
				"- Click 'BG Move' to drag background.\n" +
				"- Click 'Item Move' to drag menu items.\n" +
				"- Right-Click item to delete.\n" +
				"- Ctrl+Z / Ctrl+Y to Undo/Redo.";
			editorBG.visible = true;
			checkeredBg.visible = true;
			openSubState(new HELPSubState());
		}

		if (FlxG.keys.justPressed.F1)
		{
			var panelVisible:Bool = !editorPanelBG.visible;
			editorPanelBG.visible = panelVisible;
			allowBackgroundMove.visible = panelVisible;
			allowMenuItemMove.visible = panelVisible;
			saveButton.visible = panelVisible;
			undoButton.visible = panelVisible;
			redoButton.visible = panelVisible;
			objectCheckBtn.visible = panelVisible;
			resetBack.visible = panelVisible;
			bgPathInput.visible = panelVisible;
			loadBgBtn.visible = panelVisible;
			btnNameInput.visible = panelVisible;
			idleAnimInput.visible = panelVisible;
			selectedAnimInput.visible = panelVisible;
			addButtonBtn.visible = panelVisible;
		}
	}

	override public function closeSubState()
	{
		super.closeSubState();
		editorBG.visible = false;
		checkeredBg.visible = false;
	}

	function handleMenuItemRemoval()
	{
		if (FlxG.mouse.justPressedRight)
		{
			for (i in 0...menuItems.members.length)
			{
				var item = menuItems.members[i];
				if (item != null && FlxG.mouse.overlaps(item))
				{
					var opt = menuJson.options[i];
					var action:MenuEditAction = {
						index: i,
						name: opt.name,
						x: opt.x,
						y: opt.y,
						goesToState: opt.goesToState
					};
					undoStack.push(action);
					redoStack = [];

					menuItems.remove(item, true);
					menuJson.options.splice(i, 1);
					optionShit.splice(i, 1);
					if (draggedItem == item)
					{
						draggingItem = false;
						draggedItem = null;
					}

					rebuildMenuItems();
					break;
				}
			}
		}
	}

	function undoAction()
	{
		if (undoStack.length > 0)
		{
			var action = undoStack.pop();
			redoStack.push(action);
			var optData = {
				name: action.name,
				x: action.x,
				y: action.y,
				goesToState: action.goesToState
			};

			if (action.index <= menuJson.options.length)
			{
				menuJson.options.insert(action.index, optData);
				optionShit.insert(action.index, action.name);
			}
			else
			{
				menuJson.options.push(optData);
				optionShit.push(action.name);
			}

			rebuildMenuItems();
		}
	}

	function redoAction()
	{
		if (redoStack.length > 0)
		{
			var action = redoStack.pop();
			undoStack.push(action);

			if (action.index < menuJson.options.length && menuJson.options[action.index].name == action.name)
			{
				menuJson.options.splice(action.index, 1);
				optionShit.splice(action.index, 1);
			}
			else
			{
				for (i in 0...menuJson.options.length)
				{
					if (menuJson.options[i].name == action.name)
					{
						menuJson.options.splice(i, 1);
						optionShit.splice(i, 1);
						break;
					}
				}
			}

			rebuildMenuItems();
		}
	}

	function handleUndoRedoShortcuts()
	{
		var controlPressed:Bool = FlxG.keys.pressed.CONTROL;
		if (controlPressed && FlxG.keys.justPressed.Z) undoAction();
		if (controlPressed && FlxG.keys.justPressed.Y) redoAction();
	}

	function handleBackgroundDragging()
	{
		if (!canBackgroundMove) return;

		if (FlxG.mouse.pressed && !draggingBg)
		{
			if (FlxG.mouse.overlaps(bg))
			{
				draggingBg = true;
				bgDragOffsetX = FlxG.mouse.x - bg.x;
				bgDragOffsetY = FlxG.mouse.y - bg.y;
			}
		}

		if (!FlxG.mouse.pressed)
		{
			draggingBg = false;
			return;
		}

		if (draggingBg)
		{
			bg.x = FlxG.mouse.x - bgDragOffsetX;
			bg.y = FlxG.mouse.y - bgDragOffsetY;

			if (menuJson != null)
			{
				menuJson.backgroundX = bg.x;
				menuJson.backgroundY = bg.y;
			}
		}
	}

	function handleMenuItemDragging()
	{
		if (!canMenuItemMove) return;

		if (FlxG.mouse.pressed && !draggingItem)
		{
			for (item in menuItems)
			{
				if (FlxG.mouse.overlaps(item))
				{
					draggingItem = true;
					draggedItem = item;
					itemDragOffsetX = FlxG.mouse.x - item.x;
					itemDragOffsetY = FlxG.mouse.y - item.y;
					break;
				}
			}
		}

		if (!FlxG.mouse.pressed)
		{
			draggingItem = false;
			draggedItem = null;
			return;
		}

		if (draggingItem && draggedItem != null)
		{
			draggedItem.x = FlxG.mouse.x - itemDragOffsetX;
			draggedItem.y = FlxG.mouse.y - itemDragOffsetY;

			for (i in 0...menuItems.members.length)
			{
				if (menuItems.members[i] == draggedItem)
				{
					if (menuJson != null && menuJson.options[i] != null)
					{
						menuJson.options[i].x = draggedItem.x;
						menuJson.options[i].y = draggedItem.y;
					}
					break;
				}
			}
		}
	}
}