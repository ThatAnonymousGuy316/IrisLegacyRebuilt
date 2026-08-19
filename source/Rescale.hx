package;

import flixel.FlxG;
import openfl.system.Capabilities;
import openfl.Lib;

class Rescale {
    public static var screenResX:Int = 0;
    public static var screenResY:Int = 0;
    public static var rescalacion:Float = 1;
    public static var rescw:Float = 1;

    public static function update():Void {
        screenResX = Lib.current.stage.stageWidth;
        screenResY = Lib.current.stage.stageHeight;
        rescalacion = getScale();
        rescw = getScale2();
    }

    public static function init():Void {
        screenResX = Lib.current.stage.stageWidth;
        screenResY = Lib.current.stage.stageHeight;

        FlxG.resizeGame(screenResX, screenResY);
        
        rescalacion = getScale();
        rescw = getScale2();
    }

    public static function getScale():Float {
        return (screenResY > 0) ? screenResY / 720 : FlxG.height / 720;
    }

    public static function getScale2():Float {
        return screenResY;
    }
}
