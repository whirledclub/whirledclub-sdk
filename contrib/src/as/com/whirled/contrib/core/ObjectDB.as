package com.whirled.contrib.core {

import com.threerings.util.Assert;
import com.threerings.util.HashMap;
import com.threerings.util.ArrayUtil;

import flash.display.DisplayObject;
import flash.display.DisplayObjectContainer;
import flash.display.Sprite;
import com.whirled.contrib.core.components.SceneComponent;

public class ObjectDB
{
    public function ObjectDB ()
    {
    }

    /**
     * Adds an AppObject to the database. The AppObject must not be owned by another database.
     * If displayParent is not null, obj's attached DisplayObject will be added as a child
     * of displayParent.
     */
    public function addObject (obj :AppObject, displayParent :DisplayObjectContainer = null) :uint
    {
        Assert.isTrue(null != obj);
        Assert.isTrue(null == obj._parentDB);

        // if there's no free slot in our objects array,
        // make a new one
        if (_freeIndexes.length == 0) {
            _freeIndexes.push(uint(_objects.length));
            _objects.push(null);
        }

        Assert.isTrue(_freeIndexes.length > 0);
        var index :uint = _freeIndexes.pop();
        Assert.isTrue(index >= 0 && index < _objects.length);
        Assert.isTrue(_objects[index] == null);

        _objects[index] = obj;

        obj._objectId = createObjectId(index);
        obj._parentDB = this;

        // does the object have a name?
        if (null != obj.objectName) {
            Assert.isTrue(_namedObjects.get(obj.objectName) == null, "Can't add two objects with the same name to the same mode.");
            _namedObjects.put(obj.objectName, obj);
        }

        // is the object in any groups?
        var groupNames :Array = obj.objectGroups;
        if (null != groupNames) {
            for each (var groupName :* in groupNames) {
                var groupArray :Array = (_groupedObjects.get(groupName) as Array);
                if (null == groupArray) {
                    groupArray = new Array();
                    _groupedObjects.put(groupName, groupArray);
                }

                groupArray.push(obj);
            }
        }

        // should the object be attached to a display parent?
        // (this is purely a convenience - the client is free to
        // do the attaching themselves)
        if (null != displayParent) {
            var sc :SceneComponent = (obj as SceneComponent);
            Assert.isNotNull(sc);
            Assert.isNotNull(sc.displayObject);
            
            displayParent.addChild(sc.displayObject);
        }

        obj.addedToDBInternal(this);

        ++_objectCount;

        return obj.id;
    }

    /** Removes an AppObject from the mode. */
    public function destroyObject (id :uint) :void
    {
        var obj :AppObject = getObject(id);

        if (null == obj) {
            return;
        }

        obj._parentDB = null;

        var index :uint = idToIndex(id);

        Assert.isTrue(obj == _objects[index]);

        _objects[index] = null;
        _freeIndexes.unshift(index); // we have a new free index

        // does the object have a name?
        if (null != obj.objectName) {
            Assert.isTrue(_namedObjects.get(obj.objectName) == obj);
            _namedObjects.put(obj.objectName, null);
        }

        // is the object in any groups?
        var groupNames :Array = obj.objectGroups;
        if (null != groupNames) {
            for each (var groupName :* in groupNames) {
                var groupArray :Array = (_groupedObjects.get(groupName) as Array);
                Assert.isTrue(null != groupArray);
                var wasInArray :Boolean = ArrayUtil.removeFirst(groupArray, obj);
                Assert.isTrue(wasInArray);
            }
        }

        // if the object is attached to a DisplayObject, and if that
        // DisplayObject is in a display list, remove it from the display list
        // so that it will no longer be drawn to the screen
        var sc :SceneComponent = (obj as SceneComponent);
        if (null != sc && null != sc.displayObject && null != sc.displayObject.parent) {
            sc.displayObject.parent.removeChild(sc.displayObject);
        }

        obj.removedFromDBInternal(this);

        --_objectCount;
    }

    public function getObject (id :uint) :AppObject
    {
        var index :uint = idToIndex(id);

        if (index < _objects.length) {

            var obj :AppObject = _objects[index];

            if (null != obj && idToSerialNumber(id) == idToSerialNumber(obj.id)) {
                return obj;
            }
        }

        return null;
    }

    /** Returns the object in this mode with the given name, or null if no such object exists. */
    public function getObjectNamed (name :String) :AppObject
    {
        return (_namedObjects.get(name) as AppObject);
    }

    /** Returns the set of objects in the given group. This set must not be modified by client code. */
    public function getObjectsInGroup (groupName :String) :Array
    {
        var objects :Array = (_groupedObjects.get(groupName) as Array);

        return (null != objects ? objects : new Array());
    }

    /** Called once per update tick. Updates all objects in the mode. */
    public function update (dt :Number) :void
    {
        // update all objects in this mode
        // there may be holes in the array, so check each object against null
        for each (var obj :AppObject in _objects) {
            if (null != obj) {
                obj.updateInternal(dt);
            }
        }
    }

    /** Sends a message to every object in the database. */
    public function broadcastMessage (msg :ObjectMessage) :void
    {
        for each (var obj :AppObject in _objects) {
            if (null != obj) {
                obj.receiveMessageInternal(msg);
            }
        }
    }

    /** Sends a message to a specific object. */
    public function sendMessageTo (msg :ObjectMessage, targetId :uint) :void
    {
        var target :AppObject = this.getObject(targetId);
        if (null != target) {
            target.receiveMessageInternal(msg);
        }
    }

    /** Sends a message to the object with the given name. */
    public function sendMessageToNamedObject (msg :ObjectMessage, objectName :String) :void
    {
        var target :AppObject = this.getObjectNamed(objectName);
        if (null != target) {
            target.receiveMessageInternal(msg);
        }
    }

    /** Sends a message to each object in the given group. */
    public function sendMessageToGroup (msg :ObjectMessage, groupName :String) :void
    {
        var objs :Array = this.getObjectsInGroup(groupName);
        for each (var obj :AppObject in objs) {
            obj.receiveMessageInternal(msg);
        }
    }

    internal function createObjectId (index :uint) :uint
    {
        Assert.isTrue(index <= 0x0000FFFF);

        var sn :uint = _serialNumberCounter++;

        if (_serialNumberCounter > 0x0000FFFF) {
            _serialNumberCounter = 1; // never generate a sn of 0
        }

        return ((sn << 16) | (index & 0x0000FFFF));
    }

    internal function idToIndex (id :uint) :uint
    {
        return (id & 0x0000FFFF);
    }

    internal function idToSerialNumber (id :uint) :uint
    {
        return (id >> 16);
    }

    public function get objectCount () :uint
    {
        return _objectCount;
    }

    protected var _objectCount :uint;
    protected var _objects :Array = new Array();
    protected var _freeIndexes :Array = new Array();
    protected var _serialNumberCounter :uint = 1;

    /** stores a mapping from String to Object */
    protected var _namedObjects :HashMap = new HashMap();

    /** stores a mapping from String to Array */
    protected var _groupedObjects :HashMap = new HashMap();
}

}
