//
// $Id$

package com.whirled.game {

import flash.events.KeyboardEvent;

import flash.display.DisplayObject;

import flash.geom.Point;

import com.whirled.AbstractSubControl;

/**
 * Dispatched when a key is pressed when the game has focus.
 *
 * @eventType flash.events.KeyboardEvent.KEY_DOWN
 */
[Event(name="keyDown", type="flash.events.KeyboardEvent")]

/**
 * Dispatched when a key is released when the game has focus.
 *
 * @eventType flash.events.KeyboardEvent.KEY_UP
 */
[Event(name="keyUp", type="flash.events.KeyboardEvent")]

/**
 * Dispatched when the size of the game area changes.
 *
 * @eventType com.whirled.game.SizeChangedEvent.SIZE_CHANGED
 */
[Event(name="SizeChanged", type="com.whirled.game.SizeChangedEvent")]

/**
 * Provides access to the 'local' game services. Do not instantiate this class yourself,
 * access it via GameControl.local.
 */
public class LocalSubControl extends AbstractSubControl
{
    /**
     * @private Constructed via GameControl.
     */
    public function LocalSubControl (parent :GameControl)
    {
        super(parent);
    }

    /**
     * @inheritDoc
     */
    override public function addEventListener (
        type :String, listener :Function, useCapture :Boolean = false,
        priority :int = 0, useWeakReference :Boolean = false) :void
    {
        super.addEventListener(type, listener, useCapture, priority, useWeakReference);

        switch (type) {
        case KeyboardEvent.KEY_UP:
        case KeyboardEvent.KEY_DOWN:
            if (hasEventListener(type)) { // ensure it was added
                callHostCode("alterKeyEvents_v1", type, true);
            }
            break;
        }
    }

    /**
     * @inheritDoc
     */
    override public function removeEventListener (
        type :String, listener :Function, useCapture :Boolean = false) :void
    {
        super.removeEventListener(type, listener, useCapture);

        switch (type) {
        case KeyboardEvent.KEY_UP:
        case KeyboardEvent.KEY_DOWN:
            if (!hasEventListener(type)) { // once it's no longer needed
                callHostCode("alterKeyEvents_v1", type, false);
            }
            break;
        }
    }

    /**
     * Get the size of the game area, expressed as a Point
     * (x = width, y = height).
     */
    public function getSize () :Point
    {
        return callHostCode("getSize_v1") as Point;
    }

    /**
     * Display a feedback chat message for the local player only, no other players
     * or observers will see it.
     */
    public function feedback (msg :String) :void
    {
        callHostCode("localChat_v1", msg);
    }

    /**
     * Run the specified text through the user's chat filter. This is optional, you can use
     * it to clean up user-entered text.
     *
     * @return the filtered text, or null if it was so bad it's gone.
     */
    public function filter (text :String) :String
    {
        return (callHostCode("filter_v1", text) as String);
    }

    /**
     * Return the headshot for the given occupant in the form of a DisplayObject.
     *
     * The objects are now *not* cached in the backend, so each request will return a brand
     * new headshot. You should save a reference to these in your game if you will be
     * re-using headshots, but now you may also get two headshots for the same player if you
     * want to display them in two places.
     *
     * The DisplayObject returned is always 80x60 pixels large. If the player's actual headshot
     * is smaller than 80x60, it will be centered inside the 80x60 area.
     *
     * @param occupantId the player for which to get a headshot.
     */
    public function getHeadShot (occupantId :int) :DisplayObject
    {
        return callHostCode("getHeadShot_v2", occupantId) as DisplayObject;
    }

    /**
     * Set the frame rate to use in your game. The default is 30fps, the
     * same frame rate used in whirled rooms. The actual frame rate may be bounded on the lower
     * end (for example, we may not let it go lower than 15fps) so that the rest of the user
     * interface doesn't become annoying or unusable.
     */
    public function setFrameRate (frameRate :Number = 30) :void
    {
        callHostCode("setFrameRate_v1", frameRate);
    }

    /**
     * Set the stage quality to use in your game. The default is MEDIUM, the same quality
     * used in whirled rooms.
     */
    public function setStageQuality (quality :String = "medium" /* == StageQuality.MEDIUM */) :void
    {
        callHostCode("setStageQuality_v1", quality);
    }

    /**
     * Set whether the rematch/replay button is shown at the end of the game. It is shown
     * by default, but some games may not support rematching and so should hide the button.
     *
     * <b>Note:</b> this function changes local display only; other clients will not be affected.
     */
    public function setShowReplay (show :Boolean) :void
    {
        callHostCode("setShowReplay_v1", show);
    }

    /**
     * Set a label to be shown above the occupants list in the game.
     * Set to null to remove the label.
     *
     * <b>Note:</b> this function changes local display only; other clients will not be affected.
     */
    public function setOccupantsLabel (label :String) :void
    {
        callHostCode("setOccupantsLabel_v1", label);
    }

    /**
     * Clear all the scores displayed in the occupants list.
     *
     * <b>Note:</b> this function changes local display only; other clients will not be affected.
     *
     * @param clearValue a value to set all the scores to, or null to not show anything.
     * @param sortValuesToo if true, also clear the sort values, returning the list
     * to the default sort order.
     */
    public function clearScores (clearValue :Object = null, sortValuesToo :Boolean = false) :void
    {
        callHostCode("clearScores_v1", clearValue, sortValuesToo);
    }

    /**
     * Set scores for seated players.
     *
     * <b>Note:</b> this function changes local display only; other clients will not be affected.
     *
     * @param scores an array of 'score' values that must correspond to the seated players.
     * The scores may be numeric or String and will be displayed after the player names.
     * @param sortValues an array of sorting values that must correpond to the seated players.
     * If not specified then the scoreValues are used to sort the occupants list.
     */
    public function setPlayerScores (scores :Array, sortValues :Array = null) :void
    {
        callHostCode("setPlayerScores_v1", scores, sortValues);
    }

    /**
     * Set score or sortValue values for occupants. You may want to call clearScores prior
     * to using this method to ensure that occupants that you don't specify are cleared out.
     * You may use this method to update the "score" and sorting value for any subset of
     * occupants in the game. You can update the score for one player having their occupantId
     * as the only key. You can even set a "score" for any watchers.
     *
     * <b>Note:</b> this function changes local display only; other clients will not be affected.
     *
     * @param scores an Object mapping occupantId to a score value (which may be a String or
     * numeric), or to a two-dimensional array containing the score value and the sortValue.
     */
    public function setMappedScores (scores :Object) :void
    {
        callHostCode("setMappedScores_v1", scores);
    }

    /**
     * Instructs the game client to open the appropriate location in the game's shop
     */
    public function showGameShop (itemType :String, catalogId :int = 0) :void
    {
        callHostCode("showGameShop_v1", itemType, catalogId);
    }

    /**
     * @private
     */
    override protected function setUserProps (o :Object) :void
    {
        super.setUserProps(o);

        o["dispatchEvent_v1"] = dispatch; // for re-dispatching keyboard events
        o["sizeChanged_v1"] = sizeChanged_v1;
    }

    /**
     * Private method to generate a SizeChangedEvent.
     */
    private function sizeChanged_v1 (size :Point) :void
    {
        dispatch(new SizeChangedEvent(size));
    }
}
}
