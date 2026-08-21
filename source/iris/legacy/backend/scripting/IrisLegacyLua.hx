package iris.legacy.backend.scripting;

import llua.Lua;
import llua.LuaL;
import llua.State;
import llua.Convert;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

/*
this
is
very
cool
*/

class IrisLegacyLua
{
    public static var Function_Stop:Dynamic = 1;
	public static var Function_Continue:Dynamic = 0;

    public var lua:State = null;
    public var scriptName:String = '';

    public function new(script:String)
    {
        init(script);
        start(script);
        presetVariables();
        presetFunctions();
    }

    public function init(script:String)
    {
        lua = LuaL.newstate();
		LuaL.openlibs(lua);
		Lua.init_callbacks(lua);
    }

    public function start(script:String)
    {
        var result:Dynamic = LuaL.dofile(lua, script);
		var resultStr:String = Lua.tostring(lua, result);
		if(resultStr != null && result != 0) {
			lime.app.Application.current.window.alert(resultStr, 'Error on .LUA script!');
			trace('Error on .LUA script! ' + resultStr);
			lua = null;
			return;
		}

        scriptName = haxe.io.Path.withoutExtension(haxe.io.Path.withoutDirectory(script));
    }

    public function presetVariables()
    {
        set('Function_Stop', Function_Stop);
		set('Function_Continue', Function_Continue);

        set('require', false);
		set('os', false);
    }

    public function presetFunctions()
    {

    }
    
    public function set(variable:String, data:Dynamic) {
		if(lua == null) {
			return;
		}

		Convert.toLua(lua, data);
		Lua.setglobal(lua, variable);
	}

    public function call(event:String, args:Array<Dynamic>):Dynamic {
		if(lua == null) {
			return Function_Continue;
		}

		Lua.getglobal(lua, event);

		for (arg in args) {
			Convert.toLua(lua, arg);
		}

		var result:Null<Int> = Lua.pcall(lua, args.length, 1, 0);
		if(result != null && resultIsAllowed(lua, result)) {
			/*var resultStr:String = Lua.tostring(lua, result);
			var error:String = Lua.tostring(lua, -1);
			Lua.pop(lua, 1);*/
			if(Lua.type(lua, -1) == Lua.LUA_TSTRING) {
				var error:String = Lua.tostring(lua, -1);
				Lua.pop(lua, 1);
				if(error == 'attempt to call a nil value') { //Makes it ignore warnings and not break stuff if you didn't put the functions on your lua file
					return Function_Continue;
				}
			}

			var conv:Dynamic = Convert.fromLua(lua, result);
			return conv;
		}
		return Function_Continue;
	}
}