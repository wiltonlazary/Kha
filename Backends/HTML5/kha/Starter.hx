package kha;

import js.Browser;
import js.html.audio.DynamicsCompressorNode;
import js.html.CanvasElement;
import js.html.Event;
import js.html.EventListener;
import js.html.KeyboardEvent;
import js.html.MouseEvent;
import kha.Game;
import kha.Key;
import kha.Loader;
import js.Lib;
import js.Browser;

class Starter {
	static var game : Game;
	static var painter : Painter;
	static var pressedKeys : Array<Bool>;
	static var lastPressedKey : Int;
	static var pressedKeyToChar : Array<String>;
	static var buttonspressed : Array<Bool>;
	
	public function new() {
		haxe.Log.trace = untyped js.Boot.__trace; // Hack for JS trace problems
		
		pressedKeys = new Array<Bool>();
		for (i in 0...256) pressedKeys.push(false);
		lastPressedKey = null;
		pressedKeyToChar = new Array<String>();
		for (i in 0...256) pressedKeys.push(null);
		buttonspressed = new Array<Bool>();
		for (i in 0...10) buttonspressed.push(false);
		kha.js.Image.init();
		Loader.init(new kha.js.Loader());
		Storage.init(new kha.js.Storage());
		Scheduler.init();
	}
	
	function checkGamepadButton(pad : Dynamic, num : Int, button : kha.Button) {
		if (buttonspressed[num]) {
			if (pad.buttons[num] < 0.5) {
				game.buttonUp(button);
				buttonspressed[num] = false;
			}
		}
		else {
			if (pad.buttons[num] > 0.5) {
				game.buttonDown(button);
				buttonspressed[num] = true;
			}
		}
	}
	
	public function start(game: Game): Void {
		Starter.game = game;
		Configuration.setScreen(new EmptyScreen(Color.fromBytes(0, 0, 0)));
		Loader.the.loadProject(loadFinished);
	}
	
	public function loadFinished() {
		Loader.the.initProject();
		
		var canvas : Dynamic = Browser.document.getElementById("khanvas");
		
		var widthTransform : Float = canvas.width / Loader.the.width;
		var heightTransform : Float = canvas.height / Loader.the.height;
		var transform : Float = Math.min(widthTransform, heightTransform);
		
		if (Loader.the.width > 0 && Loader.the.height > 0) {
			game.width = Math.round(Loader.the.width * transform);
			game.height = Math.round(Loader.the.height * transform);
		}

		try {
			if (canvas.getContext("experimental-webgl") != null) {
				Sys.gl = canvas.getContext("experimental-webgl");
				//Sys.gl.scale(transform, transform);
				Sys.init(true);
				painter = new ShaderPainter(game.width, game.height);
			}
		}
		catch (e : Dynamic) {
			trace(e);
		}
		if (painter == null) {
			Sys.init(false);
			painter = new kha.js.Painter(canvas.getContext("2d"), game.width, game.height);
			canvas.getContext("2d").scale(transform, transform);
		}

		Scheduler.start();
		
		var window: Dynamic = Browser.window;
		var requestAnimationFrame = window.requestAnimationFrame;
		if (requestAnimationFrame == null) requestAnimationFrame = window.mozRequestAnimationFrame;
		if (requestAnimationFrame == null) requestAnimationFrame = window.webkitRequestAnimationFrame;
		if (requestAnimationFrame == null) requestAnimationFrame = window.msRequestAnimationFrame;
		
		function animate(timestamp) {
			var window : Dynamic = Browser.window;
			if (requestAnimationFrame == null) window.setTimeout(animate, 1000.0 / 60.0);
			else requestAnimationFrame(animate);
			
			var gamepads : Dynamic = untyped __js__("navigator.gamepads");
			if (gamepads == null) gamepads = untyped __js__("navigator.webkitGamepads");
			if (gamepads == null) gamepads = untyped __js__("navigator.mozGamepads");
			if (gamepads != null) {
				for (i in 0...gamepads.length) {
					var pad = gamepads[i];
					if (pad != null) {
						checkGamepadButton(pad, 0, Button.BUTTON_1);
						checkGamepadButton(pad, 1, Button.BUTTON_2);
						checkGamepadButton(pad, 12, Button.UP);
						checkGamepadButton(pad, 13, Button.DOWN);
						checkGamepadButton(pad, 14, Button.LEFT);
						checkGamepadButton(pad, 15, Button.RIGHT);
					}
				}
			}
			
			Scheduler.executeFrame();
			
			if (canvas.getContext) {
				painter.begin();
				Configuration.screen().render(painter);
				painter.end();
			}
		}
		
		if (requestAnimationFrame == null) window.setTimeout(animate, 1000.0 / 60.0);
		else requestAnimationFrame(animate);
		
		// Autofocus
		if (canvas.getAttribute("tabindex") == null) {
			canvas.setAttribute("tabindex", "0"); // needed for keypress events
		}
		canvas.focus();
		
		// disable context menu
		canvas.oncontextmenu = function(event: Dynamic) { event.stopPropagation(); event.preventDefault(); }
		
		//Lib.document.onmousedown = function(event : js.Event) {
		canvas.onmousedown = function(event : MouseEvent) {
			checkMouseShift(event);
			//trace ( 'mouse (${event.button}) DOWN' );
			if (event.button == 0) {
				game.mouseDown(Std.int((event.pageX - canvas.offsetLeft) / transform), Std.int((event.pageY - canvas.offsetTop) / transform));
			} else {
				game.rightMouseDown(Std.int((event.pageX - canvas.offsetLeft) / transform), Std.int((event.pageY - canvas.offsetTop) / transform));
			}
		}
		
		//Lib.document.onmouseup = function(event : js.Event) {
		canvas.onmouseup = function(event : MouseEvent) {
			checkMouseShift(event);
			//trace ( 'mouse (${event.button}) UP' );
			if (event.button == 0) {
				game.mouseUp(Std.int((event.pageX - canvas.offsetLeft) / transform), Std.int((event.pageY - canvas.offsetTop) / transform));
			} else {
				game.rightMouseUp(Std.int((event.pageX - canvas.offsetLeft) / transform), Std.int((event.pageY - canvas.offsetTop) / transform));
			}
		}
		
		//Lib.document.onmousemove = function(event : js.Event) {
		canvas.onmousemove = function(event : MouseEvent) {
			checkMouseShift(event);
			game.mouseMove(Std.int((event.pageX - canvas.offsetLeft) / transform), Std.int((event.pageY - canvas.offsetTop) / transform));
		}

		//Lib.document.onkeydown = function(event : js.Event) {
		canvas.onkeydown = keyDown;
		
		//Lib.document.onkeypress = keyPress;
		canvas.onkeypress = keyPress;
		
		//Lib.document.onkeyup = keyUp;
		canvas.onkeyup = keyUp;
		
		Browser.window.onunload = function(event: Dynamic) {
			game.onClose();
		}

		Configuration.setScreen(game);
		Configuration.screen().setInstance();
		
		game.loadFinished();
	}
	
	static function checkMouseShift(event: MouseEvent) {
		if (event.shiftKey && !pressedKeys[16]) {
			//trace ("SHIFT DOWN (mouse event)");
			pressedKeys[16] = true;
			game.keyDown(Key.SHIFT, "");
		} else if (pressedKeys[16] && !event.shiftKey) {
			//trace ("SHIFT UP (mouse event)");
			pressedKeys[16] = false;
			game.keyUp(Key.SHIFT, "");
		}
	}
	
	static function checkKeyShift(event: Dynamic) {
		if (event.shiftKey && !pressedKeys[16]) {
			//trace ("SHIFT DOWN (key event)");
			pressedKeys[16] = true;
			game.keyDown(Key.SHIFT, "");
		} else if (pressedKeys[16] && event.keyCode != 16 && !event.shiftKey) {
			//trace ("SHIFT UP (key event)");
			pressedKeys[16] = false;
			game.keyUp(Key.SHIFT, "");
		}
	}
	
	static function keyDown(event: KeyboardEvent) {
		//trace ("keyDown(keyCode: " + event.keyCode + "; charCode: " + event.charCode + "; char: '" + event.char + "'; key: '" + event.key + "')");
		
		event.stopPropagation();
		
		if (pressedKeys[event.keyCode]) {
			lastPressedKey = 0;
			event.preventDefault();
			return;
		}
		lastPressedKey = event.keyCode;
		pressedKeys[event.keyCode] = true;
		switch (lastPressedKey) {
		case 8:
			game.keyDown(Key.BACKSPACE, "");
			event.preventDefault();
		case 9:
			game.keyDown(Key.TAB, "");
			event.preventDefault();
		case 13:
			game.keyDown(Key.ENTER, "");
			event.preventDefault();
		case 16:
			game.keyDown(Key.SHIFT, "");
			//trace ("SHIFT DOWN (keyDown)");
			event.preventDefault();
		case 17:
			game.keyDown(Key.CTRL, "");
			event.preventDefault();
		case 18:
			game.keyDown(Key.ALT, "");
			event.preventDefault();
		case 27:
			game.keyDown(Key.ESC, "");
			event.preventDefault();
		case 32:
			game.keyDown(Key.CHAR, " ");
			lastPressedKey = 0;
			event.preventDefault(); // don't scroll down in IE
		case 46:
			game.keyDown(Key.DEL, "");
			event.preventDefault();
		case 38:
			game.buttonDown(Button.UP);
			event.preventDefault();
		case 40:
			game.buttonDown(Button.DOWN);
			event.preventDefault();
		case 37:
			game.buttonDown(Button.LEFT);
			event.preventDefault();
		case 39:
			game.buttonDown(Button.RIGHT);
			event.preventDefault();
		default:
			if ( !event.shiftKey && !event.altKey ) {
				var char = String.fromCharCode(lastPressedKey);
				if (lastPressedKey >= 'A'.code && lastPressedKey <= 'Z'.code) {
					char = String.fromCharCode(lastPressedKey - 'A'.code + 'a'.code);
				}
				pressedKeyToChar[lastPressedKey] = char;
				//trace ('"$char" DOWN');
				game.keyDown( Key.CHAR, char );
				lastPressedKey = 0;
			}
		}
	}
	
	static function keyPress(event: Dynamic) {
		//trace ("keyPress(keyCode: " + event.keyCode + "; charCode: " + event.charCode + "; char: '" + event.char + "'; key: '" + event.key + "')");
		
		event.preventDefault();
		event.stopPropagation();
		
		// Determine the keycode crossplatform is a bit tricky.
		// Situation will be better when Gecko implements key and char: https://developer.mozilla.org/en-US/docs/DOM/KeyboardEvent
		// We saved the keycode in keyDown() and map pressed char to that code.
		// In keyUp() we can then get the char from keycode again.
		if (lastPressedKey == 0) return;
		
		if (event.keyCode == 0) {
			// current Gecko
			var char = String.fromCharCode(event.charCode);
			
			checkKeyShift(event);
			
			game.keyDown(Key.CHAR, char);
			//trace ('"$char" DOWN');
			pressedKeyToChar[lastPressedKey] = char;
			
		}
		// DOM3
		else if (event.char != null) { // IE
			if (event.char != "") { // Gecko (planned)
				game.keyDown(Key.CHAR, event.char);
				//trace ('"${event.char}" DOWN');
				pressedKeyToChar[lastPressedKey] = event.char;
			}
		}
		
		lastPressedKey = 0;
	}
	
	static function keyUp(event: KeyboardEvent) {
		//trace ("keyUp(keyCode: " + event.keyCode + "; charCode: " + event.charCode + "; char: '" + event.char + "'; key: '" + event.key + "')");
		
		event.preventDefault();
		event.stopPropagation();
		
		checkKeyShift(event);
		
		pressedKeys[event.keyCode] = false;
		
		switch (event.keyCode) {
		case 8:
			game.keyUp(Key.BACKSPACE, "");
		case 9:
			game.keyUp(Key.TAB, "");
		case 13:
			game.keyUp(Key.ENTER, "");
		case 16:
			game.keyUp(Key.SHIFT, "");
			//trace ("SHIFT UP (keyUp)");
		case 17:
			game.keyUp(Key.CTRL, "");
		case 18:
			game.keyUp(Key.ALT, "");
		case 27:
			game.keyUp(Key.ESC, "");
		case 32:
			game.keyUp(Key.CHAR, " ");
		case 46:
			game.keyUp(Key.DEL, "");
		case 38:
			game.buttonUp(Button.UP);
		case 40:
			game.buttonUp(Button.DOWN);
		case 37:
			game.buttonUp(Button.LEFT);
		case 39:
			game.buttonUp(Button.RIGHT);
		}
		
		if (pressedKeyToChar[event.keyCode] != null) {
			game.keyUp(Key.CHAR, pressedKeyToChar[event.keyCode]);
			//trace ('"${pressedKeyToChar[event.keyCode]}" UP');
			pressedKeyToChar[event.keyCode] = null;
		}
	}
}