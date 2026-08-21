package funkin.editors.ui;

import flixel.math.FlxPoint;
import lime.ui.KeyCode;
import lime.ui.KeyModifier;
import openfl.desktop.Clipboard;
import openfl.geom.Rectangle;

class UITextBox extends UISliceSprite implements IUIFocusable {
        public var label:UIText;

        public var position:Int = 0;
        public var multiline:Bool = false;
        public var caretSpr:FlxSprite;

        public var onChange:String->Void;

        /**
         * When this box lives outside a UIState (e.g. inside a MusicBeatState),
         * the normal `focused` getter that reads UIState.state.focusedElement
         * will always return false.  Set this flag manually so the caret,
         * selected frame-offset and onChange callback still work.
         */
        public var externallyFocused:Bool = false;

        var __wasFocused:Bool = false;

        public function new(x:Float, y:Float, text:String = "", width:Int = 320, height:Int = 32, multiline:Bool = false, small:Bool = false) {
                super(x, y, width, height, 'editors/ui/inputbox${small ? "-small" : ""}');

                label = new UIText(0, 0, width, text, small ? 12 : 15);
                members.push(label);

                caretSpr = new FlxSprite(0, 0);
                caretSpr.makeGraphic(1, 1, -1);
                caretSpr.scale.set(1, label.size);
                caretSpr.updateHitbox();
                members.push(caretSpr);
                this.multiline = multiline;
                position = text.length;

                cursor = IBEAM;
        }

        var cacheRect:Rectangle = new Rectangle();

        public override function update(elapsed:Float) {
                // 1. Add null check for camera array
                if (selectable && hovered && FlxG.mouse.justReleased && __lastDrawCameras != null && __lastDrawCameras.length > 0) {
                        // get caret pos
                        var pos = FlxG.mouse.getScreenPosition(__lastDrawCameras[0], FlxPoint.get());
                        
                        // 2. Add null checks for the label and its textField
                        if (label != null) {
                                pos.x -= label.x;
                                pos.y -= label.y;

                                if (pos.x < 0) {
                                        position = 0;
                                } else if (label.textField != null) {
                                        var index = label.textField.getCharIndexAtPoint(pos.x, pos.y);
                                        if (index > -1)
                                                position = index;
                                        else
                                                position = label.text.length;
                                }
                        }

                        pos.put();
                }

                super.update(elapsed);

                // 3. SAFEGUARD: Stop updating if label doesn't exist
                if (label == null) return;

                // 4. SAFELY check 'focused' without crashing if UIState is missing
                var isFocused:Bool = false;
                if (UIState.state != null) {
                        try {
                                isFocused = focused;
                        } catch(e:Dynamic) {}
                }
                // Outside a UIState the normal getter always returns false;
                // honour the manually-set flag instead.
                if (externallyFocused) isFocused = true;

                var selected = selectable && isFocused;
                
                if (autoAlpha) {
                        if (selectable) {
                                alpha = label.alpha = 1;
                        } else {
                                alpha = label.alpha = 0.4;
                        }
                }

                // 5. Safe width check for textField
                var textWidth:Float = 0;
                if (label.textField != null) {
                        textWidth = label.textField.width;
                }

                var off = multiline ? 4 : ((bHeight - label.height) / 2);
                label.follow(this, label.autoSize ? (bWidth - textWidth) / 2 : 4, off);
                framesOffset = (selected ? 18 : (hovered ? 9 : 0));
                
                @:privateAccess {
                        // 6. Check caretSpr and textField before processing typing visuals
                        if (selected && caretSpr != null && label.textField != null) {
                                __wasFocused = true;
                                caretSpr.alpha = (FlxG.game.ticks % 666) >= 333 ? 1 : 0;

                                var curPos = switch (position) {
                                        case 0:
                                                FlxPoint.get(0, 0);
                                        default:
                                                if (position >= label.text.length) {
                                                        label.textField.__getCharBoundaries(label.text.length - 1, cacheRect);
                                                        FlxPoint.get(cacheRect.x + cacheRect.width, cacheRect.y);
                                                } else {
                                                        label.textField.__getCharBoundaries(position, cacheRect);
                                                        FlxPoint.get(cacheRect.x, cacheRect.y);
                                                }
                                };
                                caretSpr.follow(this, 4 + curPos.x, off + curPos.y);
                                curPos.put();
                        } else {
                                if (__wasFocused) {
                                        __wasFocused = false;
                                        if (onChange != null)
                                                onChange(label.text);
                                }
                                if (caretSpr != null) caretSpr.alpha = 0;
                        }
                }
        }
        private static var seperators:Array<String> = [
                " ", "\n", "\t", "\r", "-", "_", "=", "+", "/", "\\", "|", ",", ".", ";", ":", "!", "?", "@", "#", "$", "%", "^", "&", "*", "(", ")", "[", "]", "{",
                "}",
        ];

        public inline static function isSeperator(char:String):Bool
                return seperators.contains(char);

        public inline static function findWholeWord(text:String, pos:Int, ?isDelete:Bool = false):Null<Array<Int>> {
                if (text.length == 0)
                        return null;
                
                var start = pos;
                var end = pos;

                while (!isDelete && start > 0 && !isSeperator(text.charAt(start - 1)))
                        start--;

                while (end < text.length && !isSeperator(text.charAt(end)))
                        end++;

                if (end == pos && isSeperator(text.charAt(end - 1)))
                        start--;

                return [start, end];
        }

        public function onKeyDown(e:KeyCode, modifier:KeyModifier) {
                switch (e) {
                        case RETURN:
                                focused = false;
                                if (onChange != null)
                                        onChange(label.text);
                        case LEFT:
                                if (modifier.ctrlKey) {
                                        if (position == 0)
                                                return;

                                        var wordBounds = findWholeWord(label.text, position);
                                        if (wordBounds != null) {
                                                position = position == wordBounds[0] ? wordBounds[0] - 1 : wordBounds[0];
                                        } else {
                                                position = 0;
                                        }

                                        return;
                                }

                                changeSelection(-1);
                        case RIGHT:
                                if (modifier.ctrlKey) {
                                        if (position == label.text.length)
                                                return;

                                        var wordBounds = findWholeWord(label.text, position);
                                        if (wordBounds != null) {
                                                position = position == wordBounds[1] ? wordBounds[1] + 1 : wordBounds[1];
                                        } else {
                                                position = label.text.length;
                                        }

                                        return;
                                }

                                changeSelection(1);
                        case BACKSPACE:
                                UIState.playEditorSound(Flags.DEFAULT_EDITOR_TEXTREMOVE_SOUND);

                                if (modifier.ctrlKey) {
                                        var wordBounds = findWholeWord(label.text, position);
                                        if (wordBounds != null) {
                                                label.text = label.text.substr(0, wordBounds[0]) + label.text.substr(wordBounds[1]);
                                                position = wordBounds[0];
                                        }
                                        return;
                                }

                                if (position > 0) {
                                        label.text = label.text.substr(0, position - 1) + label.text.substr(position);
                                        changeSelection(-1);
                                }
                        case DELETE:
                                UIState.playEditorSound(Flags.DEFAULT_EDITOR_TEXTREMOVE_SOUND);

                                if (modifier.ctrlKey) {
                                        var wordBounds = findWholeWord(label.text, position, true);
                                        if (wordBounds != null) {
                                                label.text = label.text.substr(0, wordBounds[0]) + label.text.substr(wordBounds[1]);
                                                position = wordBounds[0];
                                        }
                                        return;
                                }

                                if (position < label.text.length) {
                                        label.text = label.text.substr(0, position) + label.text.substr(position + 1);
                                }
                        case HOME:
                                position = 0;
                        case END:
                                position = label.text.length;
                        case V:
                                // Hey lj here, fixed copying because before we checked if the modifier was left or right ctrl
                                // but somehow it gave a int outside of the KeyModifier's range :sob:
                                // apparently there is a boolean that just checks for you. yw :D

                                // if we are not holding ctrl, ignore
                                if (!modifier.ctrlKey) {
                                    UIState.playEditorSound(Flags.DEFAULT_EDITOR_TEXTTYPE_SOUND);
                                        return;
                                }

                                UIState.playEditorSound(Flags.DEFAULT_EDITOR_PASTE_SOUND);
                                
                                // we pasting
                                var data:String = Clipboard.generalClipboard.getData(TEXT_FORMAT);
                                if (data != null)
                                        onTextInput(data);
                        case C:
                                // if we are not holding ctrl, ignore
                                if (!modifier.ctrlKey) {
                                    UIState.playEditorSound(Flags.DEFAULT_EDITOR_TEXTTYPE_SOUND);
                                        return;
                                }

                                UIState.playEditorSound(Flags.DEFAULT_EDITOR_COPY_SOUND);

                                // copying
                                Clipboard.generalClipboard.setData(TEXT_FORMAT, label.text);
                        case X:
                                // if we are not holding ctrl, ignore
                                if (!modifier.ctrlKey) {
                                    UIState.playEditorSound(Flags.DEFAULT_EDITOR_TEXTTYPE_SOUND);
                                        return;
                                }

                                UIState.playEditorSound(Flags.DEFAULT_EDITOR_CUT_SOUND);

                                // cutting
                                Clipboard.generalClipboard.setData(TEXT_FORMAT, label.text);
                                position = 0;
                                label.text = "";
                        default:
                                if (modifier.ctrlKey || modifier.altKey || modifier.shiftKey)
                                        return;

                                UIState.playEditorSound(Flags.DEFAULT_EDITOR_TEXTTYPE_SOUND);
                }
        }

        public function changeSelection(change:Int) {
                position = Std.int(FlxMath.bound(position + change, 0, label.text.length));
        }

        public function onKeyUp(e:KeyCode, modifier:KeyModifier) {}

        public function onTextInput(text:String):Void {
                label.text = label.text.substr(0, position) + text + label.text.substr(position);
                position += text.length;
        }

        // untested, but this should be a fix for if the text wont type
        public function onTextEdit(text:String, start:Int, end:Int):Void {
                label.text = label.text.substr(0, position) + text + label.text.substr(position);
                position += text.length;
        }
}
