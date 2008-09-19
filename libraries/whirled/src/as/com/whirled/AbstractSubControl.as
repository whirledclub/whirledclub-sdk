//
// $Id$

package com.whirled {

import flash.errors.IllegalOperationError;

import flash.events.Event;

/**
 * Abstract base class. Do not instantiate.
 */
public class AbstractSubControl extends AbstractControl
{
    /**
     * @private
     */
    public function AbstractSubControl (parent :AbstractControl)
    {
        _parent = parent;
        // chain the unload events of our parent
        _parent.addEventListener(Event.UNLOAD, handleUnload, false, 0, true);
        super(null);
    }

    /**
     * @inheritDoc
     */
    override public function isConnected () :Boolean
    {
        return _parent.isConnected();
    }

    /**
     * @inheritDoc
     */
    override public function doBatch (fn :Function, ... args) :void
    {
        args.unshift(fn);
        _parent.doBatch.apply(null, args);
    }

    /**
     * @private
     */
    override protected function callHostCode (name :String, ... args) :*
    {
        return _parent.callHostCodeFriend(name, args);
    }

    /**
     * @private
     */
    internal function setUserPropsFriend (o :Object) :void
    {
        setUserProps(o);
    }

    /**
     * @private
     */
    internal function gotHostPropsFriend (o :Object) :void
    {
        gotHostProps(o);
    }

    /** @private */
    protected var _parent :AbstractControl;
}
}
