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
import haxe.Json;
import openfl.utils.Assets;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

import funkin.options.Options;
import funkin.editors.substates.HELPSubState;
import funkin.editors.substates.ResetSubstate;
import funkin.editors.ui.UITextBox;

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
	@:optional var idleAnim:String;
	@:optional var selectedAnim:String;
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

	var bgPathInput:UITextBox;
	var loadBgBtn:FlxButton;

	var btnNameInput:UITextBox;
	var idleAnimInput:UITextBox;
	var selectedAnimInput:UITextBox;
	var addButtonBtn:FlxButton;

	var currentTextBox:UITextBox = null;

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

		editorPanelBG = new FlxSprite(10, 10).makeGraphic(530, 260, FlxColor.BLACK);
		editorPanelBG.alpha = 0.6;
		editorPanelBG.scrollFactor.set();
		add(editorPanelBG);

		menuItems = new FlxTypedGroup<FlxSprite>();
		add(menuItems);

		rebuildMenuItems();

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

		bgPathInput = new UITextBox(15, 100, menuJson.background != null ? menuJson.background : "menuBG", 150, 20);
		loadBgBtn = new FlxButton(175, 100, "Load BG", function() {
			var labelText:String = bgPathInput.label.text;
			if (labelText != null && labelText.trim() != "") {
				var newBgKey:String = labelText.trim();
				bg.loadGraphic(Paths.image(newBgKey));
				menuJson.background = newBgKey;
				bg.setGraphicSize(Std.int(bg.width * 1.175));
				bg.updateHitbox();
			}
		});

		btnNameInput = new UITextBox(15, 150, "button_name", 120, 20);
		idleAnimInput = new UITextBox(145, 150, "idle prefix", 120, 20);
		selectedAnimInput = new UITextBox(275, 150, "selected prefix", 120, 20);

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
		var name:String = btnNameInput.label.text.trim();
		if (name == "" || name == "button_name") return;

		var idle:String = idleAnimInput.label.text.trim();
		if (idle == "" || idle == "idle prefix") idle = name + " basic";

		var selected:String = selectedAnimInput.label.text.trim();
		if (selected == "" || selected == "selected prefix") selected = name + " white";

		var newOpt:OptionDataJson = {
			name: name,
			x: 100,
			y: 100 + (menuJson.options.length * 80),
			goesToState: doesObjectGoToState,
			idleAnim: idle,
			selectedAnim: selected
		};

		var action:MenuEditAction = {
			index: menuJson.options.length,
			name: name,
			x: newOpt.x,
			y: newOpt.y,
			goesToState: newOpt.goesToState,
			idleAnim: idle,
			selectedAnim: selected
		};
		undoStack.push(action);
		redoStack = [];

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

		if (FlxG.mouse.justPressed)
		{
			var boxes:Array<UITextBox> = [bgPathInput, btnNameInput, idleAnimInput, selectedAnimInput];
			var clickedBox:Bool = false;

			for (box in boxes)
			{
				if (box != null && FlxG.mouse.overlaps(box))
				{
					clickedBox = true;
					if (currentTextBox != box)
					{
						if (currentTextBox != null) currentTextBox.focused = false;
						currentTextBox = box;
						currentTextBox.focused = true;
					}
					break;
				}
			}

			if (!clickedBox && currentTextBox != null)
			{
				currentTextBox.focused = false;
				currentTextBox = null;
			}
		}

		if (currentTextBox != null && currentTextBox.focused)
		{
			var dummyMod:lime.ui.KeyModifier = cast { shiftKey: false, ctrlKey: false, altKey: false, metaKey: false, numLock: false, capsLock: false };

			if (FlxG.keys.justPressed.BACKSPACE) currentTextBox.onKeyDown(BACKSPACE, dummyMod);
			if (FlxG.keys.justPressed.DELETE) currentTextBox.onKeyDown(DELETE, dummyMod);
			if (FlxG.keys.justPressed.LEFT) currentTextBox.onKeyDown(LEFT, dummyMod);
			if (FlxG.keys.justPressed.RIGHT) currentTextBox.onKeyDown(RIGHT, dummyMod);
			if (FlxG.keys.justPressed.ENTER) {
				currentTextBox.onKeyDown(RETURN, dummyMod);
				currentTextBox.focused = false;
				currentTextBox = null;
			}
			
			if (FlxG.keys.pressed.CONTROL)
			{
				dummyMod.ctrlKey = true;
				if (FlxG.keys.justPressed.C) currentTextBox.onKeyDown(C, dummyMod);
				if (FlxG.keys.justPressed.V) currentTextBox.onKeyDown(V, dummyMod);
				if (FlxG.keys.justPressed.X) currentTextBox.onKeyDown(X, dummyMod);
			}
		}

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
						goesToState: opt.goesToState,
						idleAnim: opt.idleAnim,
						selectedAnim: opt.selectedAnim
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
				goesToState: action.goesToState,
				idleAnim: action.idleAnim,
				selectedAnim: action.selectedAnim
			};

			var targetIndex = action.index;
			if (targetIndex > menuJson.options.length)
				targetIndex = menuJson.options.length;

			menuJson.options.insert(targetIndex, optData);
			optionShit.insert(targetIndex, action.name);

			rebuildMenuItems();
		}
	}

	function redoAction()
	{
		if (redoStack.length > 0)
		{
			var action = redoStack.pop();
			undoStack.push(action);

			var foundIndex:Int = -1;
			for (i in 0...menuJson.options.length)
			{
				if (menuJson.options[i].name == action.name)
				{
					foundIndex = i;
					break;
				}
			}

			if (foundIndex != -1)
			{
				menuJson.options.splice(foundIndex, 1);
				optionShit.splice(foundIndex, 1);
			}
			else
			{
				var optData = {
					name: action.name,
					x: action.x,
					y: action.y,
					goesToState: action.goesToState,
					idleAnim: action.idleAnim,
					selectedAnim: action.selectedAnim
				};
				var targetIndex = action.index;
				if (targetIndex > menuJson.options.length)
					targetIndex = menuJson.options.length;

				menuJson.options.insert(targetIndex, optData);
				optionShit.insert(targetIndex, action.name);
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