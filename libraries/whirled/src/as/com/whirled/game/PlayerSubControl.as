//
// $Id$

package com.whirled.game {

import com.whirled.AbstractSubControl;

/**
 * Dispatched when this player has been awarded coins.
 *
 * @eventType com.whirled.game.CoinsAwardedEvent.COINS_AWARDED
 */
[Event(name="CoinsAwarded", type="com.whirled.game.CoinsAwardedEvent")]

/**
 * Provides access to 'player' game services. Do not instantiate this class directly,
 * instead access it via GameControl.player.
 */
public class PlayerSubControl extends AbstractSubControl
{
    /** ID constant passed to cookie, prize and trophy functions to refer to the current player.
     * On normal flash clients, this is used as a default value and should not be changed. On
     * server agents, a valid playerId must be provided since there is no current player.
     * @see #awardTrophy()
     * @see #holdsTrophy()
     * @see #setCookie()
     * @see #getCookie()
     * @see #awardPrize() */
    public static const CURRENT_USER :int = 0;

    /**
     * @private Constructed via GameControl
     */
    public function PlayerSubControl (parent :GameControl)
    {
        super(parent);
    }

    /**
     * Get the user-specific game data for the specified occupant. The first time this is requested 
     * per game instance it will be retrieved from the database. After that, it will be returned 
     * from memory.
     *
     * @param callback the function that will be called when the cookie has loaded.
     * The callback should be of the form:
     * <listing version="3.0">
     *  function onGotUserCookie (cookie :Object, occupantId :int) :void
     *  {
     *      // read cookie
     *  }
     * </listing>
     */
    public function getCookie (callback :Function, occupantId :int = CURRENT_USER) :void
    {
        callHostCode("getCookie_v1", callback, occupantId);
    }

    /**
     * Store persistent data that can later be retrieved by an instance of this game. The maximum
     * size of this data is 4096 bytes AFTER AMF3 encoding.
     *
     * <p>Note: Clients may only set the cookie of the current player. Server agents do not
     * have a current player and therefore must pass in a valid player id.</p>
     *
     * @param playerId the id of the player whose cookie to get
     *
     * @return false if the cookie could not be encoded to 4096 bytes or less; true if the cookie
     * is going to try to be saved. There is no guarantee it will be saved and no way to find out
     * if it failed, but if it fails it will be because the shit hit the fan so hard that there's
     * nothing you can do anyway.
     */
    public function setCookie (cookie :Object, occupantId :int = CURRENT_USER) :Boolean
    {
        return Boolean(callHostCode("setCookie_v1", cookie, occupantId));
    }

    /**
     * Returns all item packs owned by this client's player (the default) or a specified player.
     *
     * <p>Note: Clients may only get the item packs of the current player. Server agents do not
     * have a current player and therefore must pass in a valid player id.</p>
     *
     * @param playerId the id of the player whose item packs to get
     */
    public function getPlayerItemPacks (playerId :int = CURRENT_USER) :Array
    {
        return (callHostCode("getPlayerItemPacks_v1", playerId) as Array);
    }

    /**
     * Returns true if this client's player (the default) or a specified player has the trophy
     * with the specified identifier.
     *
     * <p>Note: Clients may only test the trophies of the current player. Server agents do not
     * have a current player and therefore must pass in a valid player id.</p>
     *
     * @param playerId the id of the player whose trophies to test
     */
    public function holdsTrophy (ident :String, playerId :int = CURRENT_USER) :Boolean
    {
        return (callHostCode("holdsTrophy_v1", ident, playerId) as Boolean);
    }

    /**
     * Awards the specified trophy to this client's player (the default) or a specified player.
     * If the supplied trophy identifier is not valid, this will not be known until the request is
     * processed on the server, so the method will return succcessfully but no trophy will have
     * been awarded. Thus, you should be careful not to misspell your trophy identifier in your
     * code or in the associated trophy source item.
     *
     * <p>Note: Clients may award trophies to the current player. Server agents do not
     * have a current player and therefore must pass in a valid player id.</p>
     *
     * @param playerId the id of the player to award the trophy to
     * @return true if the trophy was awarded, false if the player already has that trophy.
     */
    public function awardTrophy (ident :String, playerId :int = CURRENT_USER) :Boolean
    {
        return (callHostCode("awardTrophy_v1", ident, playerId) as Boolean);
    }

    /**
     * Awards the specified prize item to this client's player (the default) or a specified player.
     * If the supplied prize identifier is not valid, this will not be known until the request is
     * processed on the server, so the method will return successfully but no prize will have been
     * awarded. Thus you should be careful not to misspell your prize identifier in your code or in
     * the associated prize item.
     *
     * <p> Note: a game is only allowed to award a prize once per game session. This is to guard
     * against bugs that might try to award many hundreds of the same prize to a user while playing
     * a game. If you *really* want to award multiple instances of a prize, you will need to make
     * different prize items with unique identifiers which all reference the same target item. </p>
     *
     * <p> Note also: because a game *can* award the same prize more than once if the player earns
     * the prize in separate game sessions, a game that wishes to only award a prize once should
     * couple the award of the prize with the award of a trophy and then structure their code like
     * so: </p>
     *
     * <pre>
     * if (_ctrl.awardTrophy("special_award_trophy")) {
     *     _ctrl.awardPrize("special_award_avatar");
     * }
     * </pre>
     *
     * <p> The first time the player accomplishes the necessary goal, they will be awarded the
     * trophy and the prize. Subsequently, awardTrophy() will return false indicating that the
     * player already has the trophy in question and the prize will not be awarded. Alternatively
     * the game could store whether or not the player has earned the prize in a user cookie. </p>
     *
     * <p>Note thirdly: Clients may only award prized to the current player. Server agents do not
     * have a current player and therefore must pass in a valid player id.</p>
     *
     * @param playerId the id of the player to award the prize to
     */
    public function awardPrize (ident :String, playerId :int = CURRENT_USER) :void
    {
        callHostCode("awardPrize_v1", ident, playerId);
    }

    /**
     * @private
     */
    override protected function setUserProps (o :Object) :void
    {
        super.setUserProps(o);

        o["flowAwarded_v1"] = flowAwarded_v1; // old names. No real point in changing it.
    }

    /**
     * Private method to post a CoinsAwardedEvent.
     * @return true if the usercode has prevented the default action.
     */
    private function flowAwarded_v1 (amount :int, percentile :int) :Boolean
    {
        var evt :CoinsAwardedEvent = new CoinsAwardedEvent(amount, percentile);
        dispatch(evt);
        return evt.isDefaultPrevented();
    }
}
}
