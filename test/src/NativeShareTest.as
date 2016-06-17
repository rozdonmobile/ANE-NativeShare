package {

import com.freshplanet.ane.AirNativeShare.AirNativeShare;
import com.freshplanet.ane.AirNativeShare.AirNativeShareObject;

import flash.display.Sprite;
import flash.text.TextField;
import com.freshplanet.ane.AirNativeShare.AirNativeShare;
import com.freshplanet.ane.AirNativeShare.AirNativeShareObject;


public class NativeShareTest extends Sprite 
{
    public function NativeShareTest() 
    {
        var textField:TextField = new TextField();
        textField.text = "Hello, World";
        addChild(textField);

        new PlainButton(this, {label : "Share"}, function():void
        {
            var myShareObject:AirNativeShareObject = new AirNativeShareObject();
            myShareObject.facebookText = "This will be shared on Facebook"
            myShareObject.facebookLink = "http://www.helpexamples.com/flash/images/image2.jpg"
            myShareObject.defaultLink = "http://www.helpexamples.com/flash/images/image2.jpg"
            myShareObject.hasDefaultLink = true

            AirNativeShare.getInstance().showShare(myShareObject)
        });
    }
}
}

import flash.display.DisplayObjectContainer;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;

class PlainButton extends Sprite
{
    function PlainButton(parent:DisplayObjectContainer=null, properties:Object=null, clickHandler:Function=null)
    {
        super();

        _props = properties;
        _label = properties ? (properties.label || "") : "";
        _color = properties ? (properties.color || 0) : 0;

        var textColor:uint = properties ? (properties.textColor || 0xFFFFFF) : 0xFFFFFF;

        textDisplay = new TextField();
        textDisplay.defaultTextFormat = new TextFormat("_sans", 24, textColor, null, null, null, null, null, TextFormatAlign.CENTER);
        textDisplay.selectable = false;
        textDisplay.autoSize = "center";
        addChild(textDisplay);

        x = _props.x || 0;
        y = _props.y || 0;

        if (parent)
            parent.addChild(this);

        if (clickHandler != null)
        {
            addEventListener(MouseEvent.CLICK, function(event:MouseEvent):void
            {
                if (clickHandler.length == 1)
                    clickHandler(event);
                else if (clickHandler.length == 0)
                    clickHandler();
            });
        }

        sizeInvalid = true;
        labelInvalid = true;

        addEventListener(Event.ENTER_FRAME, renderHandler);
    }

    private var sizeInvalid:Boolean;
    private var labelInvalid:Boolean;

    private var _label:String;
    private var _color:uint;
    private var _props:Object;

    private var textDisplay:TextField;

    private function renderHandler(event:Event):void
    {
        if (labelInvalid)
        {
            labelInvalid = false;

            textDisplay.text = _label;
        }

        if (sizeInvalid)
        {
            sizeInvalid = false;

            var w:Number = _props.width || _props.w || 100;
            var h:Number = _props.height || _props.h || 40;

            graphics.clear();
            graphics.beginFill(_color);
            graphics.drawRect(0, 0, w, h);
            graphics.endFill();

            textDisplay.x = 0;
            textDisplay.width = w;
            textDisplay.y = (h - textDisplay.height) / 2;
        }
    }
}