package funkin.editors.substates;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxAxes;
import flixel.addons.display.FlxBackdrop;

import funkin.backend.MusicBeatSubstate; // Corrected Codename Engine path

class HELPSubState extends MusicBeatSubstate
{
	public static var helpText:String = "Default Help Text";

	public function new()
	{
		super();

		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0.7;
		bg.scrollFactor.set();
		add(bg);

		var scrollingBg:FlxBackdrop = new FlxBackdrop(Paths.image('whiteDots'), FlxAxes.X, 0, 0);
		scrollingBg.velocity.set(-100, 0);
		scrollingBg.scrollFactor.set(0.9, 0.9);
		add(scrollingBg);

		var infoText:FlxText = new FlxText(0, 0, FlxG.width - 100, helpText, 32);
		infoText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		infoText.scrollFactor.set();
		infoText.screenCenter();
		add(infoText);

		var closePrompt:FlxText = new FlxText(0, FlxG.height - 40, FlxG.width, "Press ESCAPE to close", 20);
		closePrompt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.GRAY, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		closePrompt.scrollFactor.set();
		add(closePrompt);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (FlxG.keys.justPressed.ESCAPE || FlxG.keys.justPressed.BACKSPACE)
		{
			close();
		}
	}
}