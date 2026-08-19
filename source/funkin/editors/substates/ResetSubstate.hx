package funkin.editors.substates;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.addons.display.FlxBackdrop;
import flixel.util.FlxAxes;

import funkin.backend.MusicBeatSubstate;
import funkin.editors.MainMenuEditor;

class ResetSubstate extends MusicBeatSubstate
{
	var parentEditor:MainMenuEditor;
	var bgMask:FlxSprite;
	var warnText:FlxText;
	var yesBtn:FlxButton;
	var noBtn:FlxButton;

	public function new(parent:MainMenuEditor)
	{
		super();
		this.parentEditor = parent;
	}

	override function create()
	{
		super.create();

		// Semi-transparent dark overlay background
		bgMask = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bgMask.alpha = 0;
		add(bgMask);

		var scrollingBg:FlxBackdrop = new FlxBackdrop(Paths.image('whiteDots'), FlxAxes.X, 0, 0);
		scrollingBg.velocity.set(-100, 0);
		scrollingBg.scrollFactor.set(0.9, 0.9);
		add(scrollingBg);

		// Confirmation prompt text
		warnText = new FlxText(0, FlxG.height * 0.38, FlxG.width, "Are you sure you want to delete everything?", 24);
		warnText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		warnText.alpha = 0;
		add(warnText);

		// YES Button
		yesBtn = new FlxButton((FlxG.width * 0.4) - 40, FlxG.height * 0.52, "Yes", function()
		{
			if (parentEditor != null)
			{
				parentEditor.deleteAllContent();
			}
			close();
		});
		yesBtn.alpha = 0;
		add(yesBtn);

		// NO Button
		noBtn = new FlxButton((FlxG.width * 0.6) - 40, FlxG.height * 0.52, "No", function()
		{
			close();
		});
		noBtn.alpha = 0;
		add(noBtn);

		// Smooth fade-in animation
		FlxTween.tween(bgMask, {alpha: 0.7}, 0.3);
		FlxTween.tween(warnText, {alpha: 1}, 0.3);
		FlxTween.tween(yesBtn, {alpha: 1}, 0.3);
		FlxTween.tween(noBtn, {alpha: 1}, 0.3);
	}
}