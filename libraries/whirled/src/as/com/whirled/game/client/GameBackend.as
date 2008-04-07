//
// $Id$

package com.whirled.game.client {

import flash.display.DisplayObject;
import flash.display.InteractiveObject;

import flash.errors.IllegalOperationError;

import flash.events.Event;
import flash.events.EventDispatcher;
import flash.events.IEventDispatcher;
import flash.events.KeyboardEvent;
import flash.events.MouseEvent;

import flash.geom.Point;
import flash.geom.Rectangle;

import flash.utils.ByteArray;
import flash.utils.Dictionary;

import com.threerings.io.TypedArray;

import com.threerings.util.ArrayUtil;
import com.threerings.util.ClassUtil;
import com.threerings.util.Integer;
import com.threerings.util.Iterator;
import com.threerings.util.Log;
import com.threerings.util.MessageBundle;
import com.threerings.util.Name;
import com.threerings.util.ObjectMarshaller;
import com.threerings.util.StringUtil;
import com.threerings.util.Wrapped;

import com.threerings.presents.client.ConfirmAdapter;
import com.threerings.presents.client.ResultWrapper;
import com.threerings.presents.client.InvocationService_ConfirmListener;
import com.threerings.presents.client.InvocationService_ResultListener;

import com.threerings.presents.dobj.ElementUpdateListener;
import com.threerings.presents.dobj.ElementUpdatedEvent;
import com.threerings.presents.dobj.EntryAddedEvent;
import com.threerings.presents.dobj.EntryRemovedEvent;
import com.threerings.presents.dobj.EntryUpdatedEvent;
import com.threerings.presents.dobj.MessageAdapter;
import com.threerings.presents.dobj.MessageEvent;
import com.threerings.presents.dobj.MessageListener;
import com.threerings.presents.dobj.ObjectAddedEvent;
import com.threerings.presents.dobj.ObjectRemovedEvent;
import com.threerings.presents.dobj.OidListListener;
import com.threerings.presents.dobj.SetListener;

import com.threerings.crowd.chat.client.ChatDisplay;
import com.threerings.crowd.chat.data.ChatCodes;
import com.threerings.crowd.chat.data.ChatMessage;
import com.threerings.crowd.chat.data.UserMessage;

import com.threerings.crowd.data.BodyObject;
import com.threerings.crowd.data.OccupantInfo;
import com.threerings.crowd.data.PlaceObject;
import com.threerings.crowd.util.CrowdContext;

import com.threerings.parlor.game.data.GameObject;

import com.whirled.game.data.GameData;
import com.whirled.game.data.ItemData;
import com.whirled.game.data.LevelData;
import com.whirled.game.data.PropertySetEvent;
import com.whirled.game.data.PropertySetListener;
import com.whirled.game.data.TrophyData;
import com.whirled.game.data.UserCookie;
import com.whirled.game.data.WhirledGameConfig;
import com.whirled.game.data.WhirledGameObject;

/**
 * Manages the backend of the game.
 */
public class GameBackend
    implements MessageListener, SetListener, ElementUpdateListener, PropertySetListener, ChatDisplay
{
    public var log :Log = Log.getLog(this);

    public function GameBackend (
        ctx :CrowdContext, gameObj :WhirledGameObject, ctrl :WhirledGameController)
    {
        _ctx = ctx;
        _gameObj = gameObj;
        _ctrl = ctrl;
        _gameData = _gameObj.getUserProps();

        _gameObj.addListener(this);
        _ctx.getClient().getClientObject().addListener(_userListener);
        _ctx.getChatDirector().addChatDisplay(this);
    }

    public function forceClassInclusion () :void
    {
        var c :Class;
        c = GameData;
        c = LevelData;
        c = ItemData;
        c = TrophyData;
    }

    public function setSharedEvents (disp :IEventDispatcher) :void
    {
        // old style listener. Deprecated 2008-02-15, but we'll probably always need it
        disp.addEventListener("ezgameQuery", handleUserCodeConnect);
        // newer listener
        disp.addEventListener("controlConnect", handleUserCodeConnect);
    }

    /**
     * Are we connected to the usercode on the front-end?
     */
    public function isConnected () :Boolean
    {
        return (_userFuncs != null);
    }

    public function setContainer (container :GameContainer) :void
    {
        _container = container;
    }

    public function shutdown () :void
    {
        _gameObj.removeListener(this);
        _ctx.getChatDirector().removeChatDisplay(this);
        _ctx.getClient().getClientObject().removeListener(_userListener);
        callUserCode("connectionClosed_v1");
        _userFuncs = null; // disconnect
    }

    /**
     * Convenience function to get our name.
     */
    public function getUsername () :Name
    {
        var body :BodyObject = (_ctx.getClient().getClientObject() as BodyObject);
        return body.getVisibleName();
    }

    /**
     * Validate that we're not shutdown.
     */
    public function validateConnected () :void
    {
        if (_userFuncs == null) {
            throw new Error("Not connected.");
        }
    }

    /**
     * Called by the WhirledGameController when the controller changes.
     */
    public function controlDidChange () :void
    {
        callUserCode("controlDidChange_v1");
    }

    /**
     * Called by the WhirledGameController when the turn changes.
     */
    public function turnDidChange () :void
    {
        callUserCode("turnDidChange_v1");
    }

    /**
     * Called by the WhirledGameController when the game starts or ends.
     */
    public function gameStateChanged (started :Boolean) :void
    {
        if (_userFuncs == null) {
            // Normally this is not needed, because callUserCode will fail gracefully if we're
            // not connected. However, this method accesses _userFuncs directly, and it may not
            // yet be set up if the user is still downloading the game media.
            return;
        }
        if (started && _userFuncs["gameDidStart_v1"] != null) {
            callUserCode("gameDidStart_v1"); // backwards compatibility
        } else if (!started && _userFuncs["gameDidEnd_v1"] != null) {
            callUserCode("gameDidEnd_v1"); // backwards compatibility
        } else {
            callUserCode("gameStateChanged_v1", started); // new hotness
        }
    }

    /**
     * Called by the WhirledGameController when a round starts or ends.
     */
    public function roundStateChanged (started :Boolean) :void
    {
        callUserCode("roundStateChanged_v1", started);
    }

    /**
     * Called by the WhirledGamePanel when the size of the game area has changed.
     */
    public function sizeChanged () :void
    {
        callUserCode("sizeChanged_v1", getSize_v1());
    }

    // from SetListener
    public function entryAdded (event :EntryAddedEvent) :void
    {
        var name :String = event.getName();
        switch (name) {
        case WhirledGameObject.USER_COOKIES:
            receivedUserCookie(event.getEntry() as UserCookie);
            break;

        case PlaceObject.OCCUPANT_INFO:
            var occInfo :OccupantInfo = (event.getEntry() as OccupantInfo)
            callUserCode("occupantChanged_v1", occInfo.bodyOid, isPlayer(occInfo.username), true);
            break;
        }
    }

    // from SetListener
    public function entryUpdated (event :EntryUpdatedEvent) :void
    {
        var name :String = event.getName();
        switch (name) {
        case WhirledGameObject.USER_COOKIES:
            receivedUserCookie(event.getEntry() as UserCookie);
            break;
        }
    }

    // from SetListener
    public function entryRemoved (event :EntryRemovedEvent) :void
    {
        var name :String = event.getName();
        switch (name) {
        case PlaceObject.OCCUPANT_INFO:
            var occInfo :OccupantInfo = (event.getOldEntry() as OccupantInfo)
            callUserCode("occupantChanged_v1", occInfo.bodyOid, isPlayer(occInfo.username), false);
            break;
        }
    }

    // from ElementUpdateListener
    public function elementUpdated (event :ElementUpdatedEvent) :void
    {
        var name :String = event.getName();
        if (name == GameObject.PLAYERS) {
            var oldPlayer :Name = (event.getOldValue() as Name);
            var newPlayer :Name = (event.getValue() as Name);
            var occInfo :OccupantInfo;
            if (oldPlayer != null) {
                occInfo = _gameObj.getOccupantInfo(oldPlayer);
                if (occInfo != null) {
                    // old player became a watcher
                    // send player-left, then occupant-added
                    callUserCode("occupantChanged_v1", occInfo.bodyOid, true, false);
                    callUserCode("occupantChanged_v1", occInfo.bodyOid, false, true);
                }
            }
            if (newPlayer != null) {
                occInfo = _gameObj.getOccupantInfo(newPlayer);
                if (occInfo != null) {
                    // watcher became a player
                    // send occupant-left, then player-added
                    callUserCode("occupantChanged_v1", occInfo.bodyOid, false, false);
                    callUserCode("occupantChanged_v1", occInfo.bodyOid, true, true);
                }
            }
        }
    }

    // from MessageListener
    public function messageReceived (event :MessageEvent) :void
    {
        var name :String = event.getName();
        if (WhirledGameObject.USER_MESSAGE == name) {
            var args :Array = event.getArgs();
            var mname :String = (args[0] as String);
            callUserCode("messageReceived_v1", mname, ObjectMarshaller.decode(args[1]));

        } else if (WhirledGameObject.GAME_CHAT == name) {
            // chat sent by the game, let's route it like localChat, which is also sent by the game
            localChat_v1(String(event.getArgs()[0]));

        } else if (WhirledGameObject.TICKER == name) {
            var targs :Array = event.getArgs();
            callUserCode("messageReceived_v1", (targs[0] as String), (targs[1] as int));
        }
    }

    // from PropertySetListener
    public function propertyWasSet (event :PropertySetEvent) :void
    {
        if (_userFuncs == null) {
            // Normally this is not needed, because callUserCode will fail gracefully if we're
            // not connected. However, this method accesses _userFuncs directly, and it may not
            // yet be set up if the user is still downloading the game media.
            return;
        }
        var key :Integer = event.getKey();
        if ("propertyWasSet_v1" in _userFuncs) {
            // dispatch the old way (Deprecated 2008-02-20, but we'll probably always need it)
            var index :int = (key == null) ? -1 : key.value;
            callUserCode("propertyWasSet_v1", event.getName(), event.getValue(),
                event.getOldValue(), index);

        } else {
            // dispatch the new way
            var keyObj :Object = (key == null) ? null : key.value;
            callUserCode("propertyWasSet_v2", event.getName(), event.getValue(),
                event.getOldValue(), keyObj);
        }
    }

    // from ChatDisplay
    public function clear () :void
    {
        // we do nothing
    }

    // from ChatDisplay
    public function displayMessage (msg :ChatMessage, alreadyDisplayed :Boolean) :Boolean
    {
        if (msg is UserMessage && msg.localtype == ChatCodes.PLACE_CHAT_TYPE) {
            var info :OccupantInfo = _gameObj.getOccupantInfo((msg as UserMessage).speaker);
            if (info != null) {
                callUserCode("userChat_v1", info.bodyOid, msg.message);
            }
        }
        return true;
    }

    /**
     * Handle key events on our container and pass them into the game.
     */
    protected function handleKeyEvent (evt :KeyboardEvent) :void
    {
        // dispatch a cloned copy of the event, so that it's safe
        _keyDispatcher(evt.clone());
    }

    /**
     * Create a logging confirm listener for service requests.
     */
    protected function createLoggingConfirmListener (
        service :String) :InvocationService_ConfirmListener
    {
        return new ConfirmAdapter(function (cause :String) :void {
            Log.getLog(this).warning(
                "Service failure [service=" + service + ", cause=" + cause + "].");
        });
    }

    /**
     * Create a logging result listener for service requests.
     */
    protected function createLoggingResultListener (
        service :String) :InvocationService_ResultListener
    {
        return new ResultWrapper(function (cause :String) :void {
            Log.getLog(this).warning(
                "Service failure [service=" + service + ", cause=" + cause + "].");
        });
    }

    /**
     * Verify that the property name / value are valid.
     */
    protected function validatePropertyChange (
        propName :String, value :Object, array :Boolean, index :int) :void
    {
        validateName(propName);

        if (array) {
            if (index < 0) {
                throw new ArgumentError("Bogus array index specified.");
            }
            if (!(_gameData[propName] is Array)) {
                throw new ArgumentError("Property " + propName + " is not an Array.");
            }
        }

        // validate the value too
        validateValue(value);
    }

    /**
     * Verify that the specified name is valid.
     */
    protected function validateName (name :String) :void
    {
        if (name == null) {
            throw new ArgumentError("Property, message, and collection names must not be null.");
        }
    }

    /**
     * Verify that the supplied chat message is valid.
     */
    protected function validateChat (msg :String) :void
    {
        if (StringUtil.isBlank(msg)) {
            throw new ArgumentError("Empty chat may not be displayed.");
        }
    }

    /**
     * Verify that the value is legal to be streamed to other clients.
     */
    protected function validateValue (value :Object) :void
    {
        ObjectMarshaller.validateValue(value);
    }

    /**
     * Called by our user listener when we receive a message event on the user object.
     */
    protected function messageReceivedOnUserObject (event :MessageEvent) :void
    {
        var name :String = event.getName();
        if (name == WhirledGameObject.COINS_AWARDED_MESSAGE) {
            var amount :int = int(event.getArgs()[0]);
            var percentile :int = int(event.getArgs()[1]);
            callUserCode("flowAwarded_v1", amount, percentile); // we still use old name

        } else if (name == (WhirledGameObject.USER_MESSAGE + ":" + _gameObj.getOid())) {
            var args :Array = event.getArgs();
            var mname :String = (args[0] as String);
            callUserCode("messageReceived_v1", mname, ObjectMarshaller.decode(args[1]));
        }
    }

    /**
     * Handle the arrival of a new UserCookie.
     */
    protected function receivedUserCookie (cookie :UserCookie) :void
    {
        if (_cookieCallbacks != null) {
            var arr :Array = (_cookieCallbacks[cookie.playerId] as Array);
            if (arr != null) {
                delete _cookieCallbacks[cookie.playerId];
                for each (var fn :Function in arr) {
                    // we want to decode every time, in case usercode mangles the value
                    var decodedValue :Object = ObjectMarshaller.decode(cookie.cookie);
                    try {
                        fn(decodedValue);
                    } catch (err :Error) {
                        log.warning("Error in user-code: " + err);
                        log.logStackTrace(err);
                    }
                }
            }
        }
    }

    /**
     * Given the specified occupant name, return if they are a player.
     */
    protected function isPlayer (occupantName :Name) :Boolean
    {
        if (_gameObj.players.length == 0) {
            return true; // party game: all occupants are players
        }
        return (-1 != _gameObj.getPlayerIndex(occupantName));
    }

    protected function handleUserCodeConnect (evt :Event) :void
    {
        var props :Object = ("props" in evt) ? Object(evt).props : evt;

        // Old-style queries were deprecated 2008-02-18, but we'll probably always need them.
        // Old: eventName: "ezQuery", userProps: "userProps", ourProps: "ezProps"
        // New: eventName: "controlConnect", userProps: "userProps", ourProps: "hostProps"
        var hostPropName :String = (evt.type == "controlConnect") ? "hostProps" : "ezProps";

        var userProps :Object = props.userProps;
        setUserCodeProperties(userProps);

        var ourProps :Object = new Object();
        populateProperties(ourProps);
        props[hostPropName] = ourProps;

        // determine whether to automatically start the game in a backwards compatible way
        var autoReady :Boolean = ("autoReady_v1" in userProps) ? userProps["autoReady_v1"] : true;

        // ok, we're now hooked-up with the game code
        _ctrl.userCodeIsConnected(autoReady);
    }

    protected function setUserCodeProperties (o :Object) :void
    {
        // here we would handle adapting old functions to a new version
        _keyDispatcher = (o["dispatchEvent_v1"] as Function);
        _userFuncs = o;
    }

    protected function callUserCode (name :String, ... args) :*
    {
        if (_userFuncs != null) {
            try {
                var func :Function = (_userFuncs[name] as Function);
                if (func != null) {
                    return func.apply(null, args);
                }

            } catch (err :Error) {
                log.warning("Error in user-code: " + err);
                log.logStackTrace(err);
            }
        }
        return undefined;
    }

    protected function populateProperties (o :Object) :void
    {
        // straight data
        o["gameData"] = _gameData;

        // convert our game config from a HashMap to a Dictionary
        var gameConfig :Object = {};
        var cfg :WhirledGameConfig = (_ctrl.getPlaceConfig() as WhirledGameConfig);
        cfg.params.forEach(function (key :Object, value :Object) :void {
            gameConfig[key] = (value is Wrapped) ? Wrapped(value).unwrap() : value;
        });
        o["gameConfig"] = gameConfig;

        // GameControl
        o["commitTransaction"] = commitTransaction_v1;
        o["focusContainer_v1"] = focusContainer_v1;
        o["startTransaction"] = startTransaction_v1;

        // .local
        o["alterKeyEvents_v1"] = alterKeyEvents_v1;
        o["backToWhirled_v1"] = backToWhirled_v1;
        o["clearScores_v1"] = clearScores_v1;
        o["filter_v1"] = filter_v1;
        o["getHeadShot_v2"] = getHeadShot_v2;
        o["getSize_v1"] = getSize_v1;
        o["localChat_v1"] = localChat_v1;
        o["setMappedScores_v1"] = setMappedScores_v1;
        o["setOccupantsLabel_v1"] = setOccupantsLabel_v1;
        o["setPlayerScores_v1"] = setPlayerScores_v1;
        o["setShowButtons_v1"] = setShowButtons_v1;

        // .net
        o["sendMessage_v2"] = sendMessage_v2;
        o["setProperty_v2"] = setProperty_v2;
        o["testAndSetProperty_v1"] = testAndSetProperty_v1;

        // .player
        o["awardPrize_v1"] = awardPrize_v1;
        o["awardTrophy_v1"] = awardTrophy_v1;
        o["getPlayerItemPacks_v1"] = getPlayerItemPacks_v1;
        o["getUserCookie_v2"] = getUserCookie_v2;
        o["holdsTrophy_v1"] = holdsTrophy_v1;
        o["setUserCookie_v1"] = setUserCookie_v1;

        // .game
        o["endGame_v2"] = endGame_v2;
        o["endGameWithScores_v1"] = endGameWithScores_v1;
        o["endGameWithWinners_v1"] = endGameWithWinners_v1;
        o["endRound_v1"] = endRound_v1;
        o["getControllerId_v1"] = getControllerId_v1;
        o["getItemPacks_v1"] = getItemPacks_v1;
        o["getLevelPacks_v1"] = getLevelPacks_v1;
        o["getMyId_v1"] = getMyId_v1;
        o["getOccupants_v1"] = getOccupants_v1;
        o["getOccupantName_v1"] = getOccupantName_v1;
        o["getRound_v1"] = getRound_v1;
        o["getTurnHolder_v1"] = getTurnHolder_v1;
        o["isInPlay_v1"] = isInPlay_v1;
        o["isMyTurn_v1"] = isMyTurn_v1;
        o["playerReady_v1"] = playerReady_v1;
        o["restartGameIn_v1"] = restartGameIn_v1;
        o["sendChat_v1"] = sendChat_v1;
        o["startNextTurn_v1"] = startNextTurn_v1;

        // .game.seating
        o["getMyPosition_v1"] = getMyPosition_v1;
        o["getPlayers_v1"] = getPlayers_v1;
        o["getPlayerPosition_v1"] = getPlayerPosition_v1;

        // .services
        o["checkDictionaryWord_v2"] = checkDictionaryWord_v2;
        o["getDictionaryLetterSet_v2"] = getDictionaryLetterSet_v2;
        o["setTicker_v1"] = setTicker_v1;

        // .services.bags
        o["getFromCollection_v2"] = getFromCollection_v2;
        o["mergeCollection_v1"] = mergeCollection_v1;
        o["populateCollection_v1"] = populateCollection_v1;

        // Old methods: backwards compatability
        o["awardFlow_v1"] = awardFlow_v1;
        o["awardFlow_v2"] = awardFlow_v2;
        o["checkDictionaryWord_v1"] = checkDictionaryWord_v1;
        o["endTurn_v2"] = startNextTurn_v1; // it's the same!
        o["getAvailableFlow_v1"] = getAvailableFlow_v1;
        o["getDictionaryLetterSet_v1"] = getDictionaryLetterSet_v1;
        o["getStageBounds_v1"] = getStageBounds_v1;
        o["setProperty_v1"] = setProperty_v1;
        o["getHeadShot_v1"] = getHeadShot_v1;
    }

    //---- GameControl -----------------------------------------------------

    protected function focusContainer_v1 () :void
    {
        validateConnected();
        _container.setFocus();
    }

    /**
     * Starts a transaction that will group all game state changes into a single message.
     */
    protected function startTransaction_v1 () :void
    {
        validateConnected();
        _ctx.getClient().getInvocationDirector().startTransaction();
    }

    /**
     * Commits a transaction started with {@link #startTransaction_v1}.
     */
    protected function commitTransaction_v1 () :void
    {
        _ctx.getClient().getInvocationDirector().commitTransaction();
    }

    //---- .local ----------------------------------------------------------

    protected function alterKeyEvents_v1 (keyEventType :String, add :Boolean) :void
    {
        validateConnected();
        if (add) {
            _container.addEventListener(keyEventType, handleKeyEvent);
        } else {
            _container.removeEventListener(keyEventType, handleKeyEvent);
        }
    }

    protected function backToWhirled_v1 (showLobby :Boolean = false) :void
    {
        _ctrl.backToWhirled(showLobby);
    }

    protected function localChat_v1 (msg :String) :void
    {
        validateChat(msg);
        // The sendChat() messages will end up being routed through this method on each client.
        // TODO: make this look distinct from other system chat
        _ctx.getChatDirector().displayInfo(null, MessageBundle.taint(msg));
    }

    protected function filter_v1 (text :String) :String
    {
        return _ctx.getChatDirector().filter(text, null, true);
    }

    /**
     * Get the size of the game area.
     */
    protected function getSize_v1 () :Point
    {
        return new Point(_container.width, _container.height);
    }

    protected function setShowButtons_v1 (rematch :Boolean, back :Boolean) :void
    {
        (_ctrl.getPlaceView() as WhirledGamePanel).setShowButtons(rematch, back, back);
    }

    protected function setOccupantsLabel_v1 (label :String) :void
    {
        (_ctrl.getPlaceView() as WhirledGamePanel).getPlayerList().setLabel(label);
    }

    protected function clearScores_v1 (clearValue :Object = null,
        sortValuesToo :Boolean = false) :void
    {
        (_ctrl.getPlaceView() as WhirledGamePanel).getPlayerList().clearScores(
            clearValue, sortValuesToo);
    }

    protected function setPlayerScores_v1 (scores :Array, sortValues :Array = null) :void
    {
        (_ctrl.getPlaceView() as WhirledGamePanel).getPlayerList().setPlayerScores(
            scores, sortValues);
    }

    protected function setMappedScores_v1 (scores :Object) :void
    {
        (_ctrl.getPlaceView() as WhirledGamePanel).getPlayerList().setMappedScores(scores);
    }

    protected function getHeadShot_v2 (occupant :int) :DisplayObject
    {
        validateConnected();

        // in here, we just return a dummy value
        return new HeadSpriteShim();
    }

    //---- .net ------------------------------------------------------------

    protected function sendMessage_v2 (messageName :String, value :Object, playerId :int) :void
    {
        validateConnected();
        validateName(messageName);
        validateValue(value);

        var encoded :Object = ObjectMarshaller.encode(value, false);
        _gameObj.whirledGameService.sendMessage(_ctx.getClient(), messageName, encoded, playerId,
                                         createLoggingConfirmListener("sendMessage"));
    }

    /**
     * Sets a property.
     *
     * Note: immediate defaults to true, even though immediate=false is the general case. We are
     * providing some backwards compatibility to old versions of setProperty_v1() that assumed
     * immediate and did not pass a 4th value.  All callers should now specify that value
     * explicitly.
     */
    protected function setProperty_v2 (
        propName :String, value :Object, key :Object, isArray :Boolean, immediate :Boolean) :void
    {
        validateConnected();
        validatePropertyChange(propName, value, isArray, int(key));

        var encoded :Object = WhirledGameObject.encodeProperty(value, (key == null));
        var ikey :Integer = (key == null) ? null : new Integer(int(key));
        _gameObj.whirledGameService.setProperty(
            _ctx.getClient(), propName, encoded, ikey, isArray,
            false, null, createLoggingConfirmListener("setProperty"));
        if (immediate) {
            // we re-decode so that it looks like it came off the net
            try {
                _gameObj.applyPropertySet(propName, WhirledGameObject.decodeProperty(encoded),
                    key, isArray);
            } catch (re :RangeError) {
                trace("Error setting property (immediate): " + re);
            }
        }
    }

    /**
     * Test and set a property. Note that the 'index' parameter was deprecated on 2008-02-20.
     * Newer code will only pass in propName, value, testValue. Older code will also pass in the
     * index, but that's ok as long as it's -1.
     */
    protected function testAndSetProperty_v1 (
        propName :String, value :Object, testValue :Object, index :int = -1) :void
    {
        // very naughty hack to support old setProperty semantics for auto-sizing arrays,
        // since Defense relies on them. TODO: robert, remove after your game is fixed up!
        if (value is Array && value.length == 0 && provideArrayCompatibility()) {
            value.length = 1000; 
        }

        if (index != -1) {
            throw new Error("Sorry, using testAndSet with an index value is no longer supported. " +
                "Update your SDK.");
        }
        validateConnected();
        validatePropertyChange(propName, value, false, 0);

        var encodedValue :Object = WhirledGameObject.encodeProperty(value, true);
        var encodedTestValue :Object = WhirledGameObject.encodeProperty(testValue, true);
        _gameObj.whirledGameService.setProperty(
            _ctx.getClient(), propName, encodedValue, null, false, true, encodedTestValue,
            createLoggingConfirmListener("testAndSetProperty"));
    }

    //---- .player ---------------------------------------------------------

    protected function getUserCookie_v2 (playerId :int, callback :Function) :void
    {
        validateConnected();
        // see if that cookie is already published
        if (_gameObj.userCookies != null) {
            var uc :UserCookie = (_gameObj.userCookies.get(playerId) as UserCookie);
            if (uc != null) {
                callback(ObjectMarshaller.decode(uc.cookie));
                return;
            }
        }

        if (_cookieCallbacks == null) {
            _cookieCallbacks = new Dictionary();
        }
        var arr :Array = (_cookieCallbacks[playerId] as Array);
        if (arr == null) {
            arr = [];
            _cookieCallbacks[playerId] = arr;
        }
        arr.push(callback);

        // request it to be made so by the server
        _gameObj.whirledGameService.getCookie(
            _ctx.getClient(), playerId, createLoggingConfirmListener("getUserCookie"));
    }

    protected function setUserCookie_v1 (cookie :Object) :Boolean
    {
        validateConnected();
        validateValue(cookie);
        var ba :ByteArray = (ObjectMarshaller.encode(cookie, false) as ByteArray);
        if (ba.length > MAX_USER_COOKIE) {
            // not saved!
            return false;
        }

        _gameObj.whirledGameService.setCookie(
            _ctx.getClient(), ba, createLoggingConfirmListener("setUserCookie"));
        return true;
    }

    protected function holdsTrophy_v1 (ident :String) :Boolean
    {
        return playerOwnsData(GameData.TROPHY_DATA, ident);
    }

    protected function awardTrophy_v1 (ident :String) :Boolean
    {
        if (playerOwnsData(GameData.TROPHY_DATA, ident)) {
            return false;
        }
        _gameObj.whirledGameService.awardTrophy(
            _ctx.getClient(), ident, new ConfirmAdapter(function (cause :String) :void {
                // TODO: change GameCodes.GAME_MSGS to "game" and use that
                _ctx.getChatDirector().displayFeedback("game", cause);
            }));
        return true;
    }

    protected function awardPrize_v1 (ident :String) :void
    {
        if (!playerOwnsData(GameData.PRIZE_MARKER, ident)) {
            _gameObj.whirledGameService.awardPrize(
                _ctx.getClient(), ident, createLoggingConfirmListener("awardPrize"));
        }
    }

    protected function getPlayerItemPacks_v1 () :Array
    {
        return getItemPacks_v1().filter(function (data :GameData, idx :int, array :Array) :Boolean {
            return playerOwnsData(data.getType(), data.ident);
        });
    }

    //---- .game -----------------------------------------------------------

    /**
     * Called by the client code when it is ready for the game to be started (if called before the
     * game ever starts) or rematched (if called after the game has ended).
     */
    protected function playerReady_v1 () :void
    {
        _ctrl.playerIsReady();
    }

    protected function sendChat_v1 (msg :String) :void
    {
        validateConnected();
        validateChat(msg);
        // Post a message to the game object, the controller will listen and call localChat().
        _gameObj.postMessage(WhirledGameObject.GAME_CHAT, [ msg ]);
    }

    protected function getLevelPacks_v1 () :Array
    {
        var packs :Array = [];
        for each (var data :GameData in _gameObj.gameData) {
            if (data.getType() != GameData.LEVEL_DATA) {
                continue;
            }
            // if the level pack is premium, only add it if we own it
            if ((data as LevelData).premium && !playerOwnsData(data.getType(), data.ident)) {
                continue;
            }
            packs.unshift({ ident: data.ident,
                            name: data.name,
                            mediaURL: data.mediaURL,
                            premium: (data as LevelData).premium });
        }
        return packs;
    }

    protected function getItemPacks_v1 () :Array
    {
        var packs :Array = [];
        for each (var data :GameData in _gameObj.gameData) {
            if (data.getType() != GameData.ITEM_DATA) {
                continue;
            }
            packs.unshift({ ident: data.ident,
                            name: data.name,
                            mediaURL: data.mediaURL });
        }
        return packs;
    }

    protected function getOccupants_v1 () :Array
    {
        validateConnected();
        var occs :Array = [];
        for (var ii :int = _gameObj.occupants.size() - 1; ii >= 0; ii--) {
            occs.push(_gameObj.occupants.get(ii));
        }
        return occs;
    }

    protected function getOccupantName_v1 (playerId :int) :String
    {
        validateConnected();
        var occInfo :OccupantInfo = (_gameObj.occupantInfo.get(playerId) as OccupantInfo);
        return (occInfo == null) ? null : occInfo.username.toString();
    }

    protected function getMyId_v1 () :int
    {
        validateConnected();
        return _ctx.getClient().getClientObject().getOid();
    }

    protected function getControllerId_v1 () :int
    {
        validateConnected();
        return _gameObj.controllerOid;
    }

    protected function getTurnHolder_v1 () :int
    {
        validateConnected();
        var occInfo :OccupantInfo = _gameObj.getOccupantInfo(_gameObj.turnHolder);
        return (occInfo == null) ? 0 : occInfo.bodyOid;
    }

    protected function getRound_v1 () :int
    {
        validateConnected();
        return _gameObj.roundId;
    }

    protected function isMyTurn_v1 () :Boolean
    {
        validateConnected();
        return getUsername().equals(_gameObj.turnHolder);
    }

    protected function isInPlay_v1 () :Boolean
    {
        validateConnected();
        return _gameObj.isInPlay();
    }

    protected function startNextTurn_v1 (nextPlayerId :int) :void
    {
        validateConnected();
        _gameObj.whirledGameService.endTurn(
            _ctx.getClient(), nextPlayerId, createLoggingConfirmListener("endTurn"));
    }

    protected function endRound_v1 (nextRoundDelay :int) :void
    {
        validateConnected();
        _gameObj.whirledGameService.endRound(
            _ctx.getClient(), nextRoundDelay, createLoggingConfirmListener("endRound"));
    }

//    protected function endGame_v2 (... winnerIds) :void
//    {
//        validateConnected();
//        _gameObj.whirledGameService.endGame(
//            _ctx.getClient(), toTypedIntArray(winnerIds), createLoggingConfirmListener("endGame"));
//    }

    protected function endGame_v2 (... winnerIds) :void
    {
        validateConnected();

        // if this is a table game, all the non-winners are losers, if it's not a table game then
        // no one is a loser because we're not going to declare that all watchers automatically be
        // considered as players and thus contribute to the winners' booty
        var loserIds :Array = [];
        // party games have a zero length players array
        for (var ii :int = 0; ii < _gameObj.players.length; ii++) {
            var occInfo :OccupantInfo = _gameObj.getOccupantInfo(_gameObj.players[ii] as Name);
            if (occInfo != null) {
                loserIds.push(occInfo.bodyOid);
            }
        }
        endGameWithWinners_v1(winnerIds, loserIds, 0) // WhirledGameControl.CASCADING_PAYOUT
    }

    protected function endGameWithWinners_v1 (
        winnerIds :Array, loserIds :Array, payoutType :int) :void
    {
        validateConnected();

        // pass the buck straight on through, the server will validate everything
        _gameObj.whirledGameService.endGameWithWinners(
            _ctx.getClient(), toTypedIntArray(winnerIds), toTypedIntArray(loserIds), payoutType,
            createLoggingConfirmListener("endGameWithWinners"));
    }

    protected function endGameWithScores_v1 (playerIds :Array, scores :Array /* of int */,
        payoutType :int) :void
    {
        validateConnected();

        // pass the buck straight on through, the server will validate everything
        _gameObj.whirledGameService.endGameWithScores(
            _ctx.getClient(), toTypedIntArray(playerIds), toTypedIntArray(scores), payoutType,
            createLoggingConfirmListener("endGameWithWinners"));
    }

    protected function restartGameIn_v1 (seconds :int) :void
    {
        validateConnected();
        _gameObj.whirledGameService.restartGameIn(
            _ctx.getClient(), seconds, createLoggingConfirmListener("restartGameIn"));
    }

    //---- .game.seating ---------------------------------------------------

    protected function getPlayerPosition_v1 (playerId :int) :int
    {
        validateConnected();
        var occInfo :OccupantInfo = (_gameObj.occupantInfo.get(playerId) as OccupantInfo);
        if (occInfo == null) {
            return -1;
        }
        return _gameObj.getPlayerIndex(occInfo.username);
    }

    protected function getMyPosition_v1 () :int
    {
        validateConnected();
        return _gameObj.getPlayerIndex(
            (_ctx.getClient().getClientObject() as BodyObject).getVisibleName());
    }

    protected function getPlayers_v1 () :Array
    {
        validateConnected();
        if (_gameObj.players.length == 0) {
            // party game
            return getOccupants_v1();
        }
        var playerIds :Array = [];
        for (var ii :int = 0; ii < _gameObj.players.length; ii++) {
            var occInfo :OccupantInfo = _gameObj.getOccupantInfo(_gameObj.players[ii] as Name);
            playerIds.push((occInfo == null) ? 0 : occInfo.bodyOid);
        }
        return playerIds;
    }

    //---- .services -------------------------------------------------------

    protected function setTicker_v1 (tickerName :String, msOfDelay :int) :void
    {
        validateConnected();
        validateName(tickerName);
        _gameObj.whirledGameService.setTicker(
            _ctx.getClient(), tickerName, msOfDelay, createLoggingConfirmListener("setTicker"));
    }

    protected function getDictionaryLetterSet_v2 (
        locale :String, dictionary :String, count :int, callback :Function) :void
    {
        validateConnected();
        var listener :InvocationService_ResultListener;
        if (callback != null) {
            var failure :Function = function (cause :String = null) :void {
                // ignore the cause, return an empty array
                callback ([]);
            }
            var success :Function = function (result :String = null) :void {
                // splice the resulting string, and return as array
                var r : Array = result.split(",");
                callback (r);
            };
            listener = new ResultWrapper(failure, success);
        } else {
            listener = createLoggingResultListener("checkDictionaryWord");
        }

        // just relay the data over to the server
        _gameObj.whirledGameService.getDictionaryLetterSet(
            _ctx.getClient(), locale, dictionary, count, listener);
    }

    protected function checkDictionaryWord_v2 (
        locale :String, dictionary :String, word :String, callback :Function) :void
    {
        validateConnected();
        var listener :InvocationService_ResultListener;
        if (callback != null) {
            var failure :Function = function (cause :String = null) :void {
                // ignore the cause, return failure
                callback (word, false);
            }
            var success :Function = function (result :Object = null) :void {
                // server returns a boolean, so convert it and send it over
                var r : Boolean = Boolean(result);
                callback (word, r);
            };
            listener = new ResultWrapper(failure, success);
        } else {
            listener = createLoggingResultListener("checkDictionaryWord");
        }

        // just relay the data over to the server
        _gameObj.whirledGameService.checkDictionaryWord(
            _ctx.getClient(), locale, dictionary, word, listener);
    }

    //---- .services.bags --------------------------------------------------

    protected function mergeCollection_v1 (srcColl :String, intoColl :String) :void
    {
        validateConnected();
        validateName(srcColl);
        validateName(intoColl);
        _gameObj.whirledGameService.mergeCollection(_ctx.getClient(),
            srcColl, intoColl, createLoggingConfirmListener("mergeCollection"));
    }

    /**
     * Helper method for setCollection and addToCollection.
     */
    protected function populateCollection_v1 (
        collName :String, values :Array, clearExisting :Boolean) :void
    {
        validateConnected();
        validateName(collName);
        if (values == null) {
            throw new ArgumentError("Collection values may not be null.");
        }
        validateValue(values);

        var encodedValues :TypedArray = (ObjectMarshaller.encode(values, true) as TypedArray);
        _gameObj.whirledGameService.addToCollection(
            _ctx.getClient(), collName, encodedValues, clearExisting,
            createLoggingConfirmListener("populateCollection"));
    }

    /**
     * Helper method for pickFromCollection and dealFromCollection.
     */
    protected function getFromCollection_v2 (
        collName :String, count :int, msgOrPropName :String, playerId :int,
        consume :Boolean, callback :Function) :void
    {
        validateConnected();
        validateName(collName);
        validateName(msgOrPropName);
        if (count < 1) {
            throw new ArgumentError("Must retrieve at least one element!");
        }

        var listener :InvocationService_ConfirmListener;
        if (callback != null) {
            // TODO: Figure out the method sig of the callback, and what it means
            var fn :Function = function (cause :String = null) :void {
                if (cause == null) {
                    callback(count);
                } else {
                    callback(parseInt(cause));
                }
            };
            listener = new ConfirmAdapter(fn, fn);

        } else {
            listener = createLoggingConfirmListener("getFromCollection");
        }

        _gameObj.whirledGameService.getFromCollection(
            _ctx.getClient(), collName, consume, count, msgOrPropName, playerId, listener);
    }

    //---- backwards compatability -----------------------------------------

    protected function getDictionaryLetterSet_v1 (
        locale :String, count :int, callback :Function) :void
    {
        getDictionaryLetterSet_v2(locale, null, count, callback);
    }

    protected function checkDictionaryWord_v1 (
        locale :String, word :String, callback :Function) :void
    {
        checkDictionaryWord_v2(locale, null, word, callback);
    }

    /**
     * Backwards compatability. Added June 18, 2007, removed Oct 24, 2007. There
     * probably aren't many/any games that used this "in the wild", so we may be able to remove
     * this at some point.
     */
    protected function getStageBounds_v1 () :Rectangle
    {
        var size :Point = getSize_v1();
        return new Rectangle(0, 0, size.x, size.y);
    }

    /** A backwards compatible method. */
    protected function getAvailableFlow_v1 () :int
    {
        return 0;
    }

    /** A backwards compatible method. */
    protected function awardFlow_v1 (amount :int) :void
    {
        // NOOP!
    }

    /** A backwards compatible method. */
    protected function awardFlow_v2 (perf :int) :int
    {
        return 0;
    }

    /** 
     * A backwards compatible method.
     *
     * Note: immediate defaults to true, even though immediate=false is the general case. We are
     * providing some backwards compatibility to old versions of setProperty_v1() that assumed
     * immediate and did not pass a 4th value.  All callers should now specify that value
     * explicitly.
     * (And of course, setProperty_v2 takes control of this situation.)
     */
    protected function setProperty_v1 (
        propName :String, value :Object, index :int, immediate :Boolean = true) :void
    {
        // very naughty hack to support old setProperty semantics for auto-sizing arrays,
        // since Defense relies on them. TODO: robert, remove after your game is fixed up!
        if (value is Array && value.length == 0 && provideArrayCompatibility()) {
            value.length = 1000; 
        }
        
        var key :Object = (index < 0) ? null : index;
        var isArray :Boolean = (key != null);
        setProperty_v2(propName, value, key, isArray, immediate);
    }

    /** 
     * A backwards compatible method.
     */
    protected function getHeadShot_v1 (occupant :int, callback :Function) :void
    {
        // this callback was defined to return a Sprite, so to preserve
        // backwards compatibility we wrap the new headshot in a sprite
        var s :HeadSpriteShim = new HeadSpriteShim();
        s.addChild(getHeadShot_v2(occupant));
        callback(s, true);
    }

    // --------------------------

    /**
     * Converts a Flash array of ints to a TypedArray for delivery over the wire to the server.
     */
    protected function toTypedIntArray (array :Array) :TypedArray
    {
        var tarray :TypedArray = TypedArray.create(int);
        tarray.addAll(array);
        return tarray;
    }

    protected function playerOwnsData (type :int, ident :String) :Boolean
    {
        return false; // this information is provided by the containing system
    }

    // TEMP TODO REMOVE XXX
    protected function provideArrayCompatibility () :Boolean
    {
        var cfg :WhirledGameConfig = _ctrl.getPlaceConfig() as WhirledGameConfig;
        var url :String = cfg.getGameDefinition().getMediaPath(cfg.getGameId());

        // Tree house defense
        return (url === "http://media.whirled.com/6c7fa832bd422899ffea685adadbf55c184edb2e.swf");
    }

    protected var _ctx :CrowdContext;

    protected var _userListener :MessageAdapter = new MessageAdapter(messageReceivedOnUserObject);

    protected var _container :GameContainer;

    protected var _gameObj :WhirledGameObject;

    /** Handles trusted clientside control. */
    protected var _ctrl :WhirledGameController;

    protected var _userFuncs :Object;

    /** The function on the GameControl which we can use to directly dispatch events to the
     * user's game. */
    protected var _keyDispatcher :Function;

    protected var _gameData :Object;

    /** playerIndex -> callback functions waiting for the cookie. */
    protected var _cookieCallbacks :Dictionary;

    protected static const MAX_USER_COOKIE :int = 4096;
}
}

import flash.display.Sprite;

class HeadSpriteShim extends Sprite
{
    override public function get width () :Number
    {
        return 80;
    }

    override public function get height () :Number
    {
        return 60;
    }
}
