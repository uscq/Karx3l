## class.lua
Is a lightweight object-oriented programming library in Lua.

Unlike other lua OOPs, `class.lua` only features on construction, destructor, function and operator overloading. No private and/or protected type for field access control is provided. We want to make the code succinct and well-format, coding on some specification instead on a complicating library.

**The following functions are provided for OOP:**


- `class(_super)` -> class -- define a class with an option super class/table `_super`;
- `new(class, ...)` -> obj -- create an object of `class` and call the lastest `class.__ctor` with  `...` if presend;
- `delete(obj)` -> nil -- delete an object, that is call the `__gc`, remove metetable, and clear field on it;
- `is_a(obj, class)` -> boolean -- return `true` if the table of `obj` is a kind of `class`;
- `typeof(obj)` -> class -- get the type class of `obj`.

**The metamethods will *NOT* inherit automatically.** For convenience, `class.lua` overrides `__tostring` and `__gc` when define.

**For Example:**

```lua
require "class"

-- define a class
-- accepts an optional table/class that the new class to inherit
local Vector2 = class()

-- construction
-- the parameter begins with an underscore means it is optional.
function Vector2:__ctor (_x, _y)
    self.__x = _x or 0
    self.__y = _y or 0
end

function Vector2:__add (v2)
    assert(is_a(v2, Vector2), 'right operator is not a Vector2')
    return new(Vector2, self.__x + v2.__x, self.__y + v2.__y)
end

function Vector2:__tostring ( )
    return string.format('[%s, %s]', tostring(self.__x), tostring(self.__y))
end

function Vector2:TestFunction ( )
    print(self, 'in vector2 was tested.')
end

-- destructor
function Vector2:__gc ( )
    print(self, 'is destructed.')
end

local Vector3 = class(Vector2)

-- any override method should involve from super class explicitly,
-- including special constructs, destructors.
function Vector3:__ctor (_x, _y, _z)
    Vector2.__ctor(self, _x, _y)
    self.__z = _z or 0
end

function Vector3:__add (v)
    local msg = 'right operator is not a compatible type of Vector3'
    assert(is_a(v, Vector3) or is_a(v, Vector2), msg)
    local x, y, z = v.__x, v.__y, v.__z or 0
    return new(Vector3, self.__x + x, self.__y + y, self.__z + z)
end

function Vector3:__tostring ( )
    local x, y, z = tostring(self.__x), tostring(self.__y), tostring(self.__z)
    return string.format('[%s, %s, %s]', x, y, z)
end

local Vector4 = class(Vector3)

function Vector4:__ctor (_x, _y, _z, _w)
    Vector3.__ctor(self, _x, _y, _z)
    self.__w = _w or 0
end

function Vector4:__tostring ( )
    local x, y, z, w = tostring(self.__x), tostring(self.__y), tostring(self.__z), tostring(self.__w)
    return string.format('[%s, %s, %s, %s]', x, y, z, w)
end

function Vector4:TestFunction ( )
    Vector3.TestFunction(self)
    print(self, 'in vector4 was tested.')
end

----
local v2 = new(Vector2, 1, 2)
local v3 = new(Vector3, 1, 4, 7)
print(v2, '+', v3, '=', v2 + v3)
print(v3, '+', v2, '=', v3 + v2)

-- __gc will be called automatically
-- or delete() is used to delete and empty it.
delete(new(Vector3))
new(Vector4, 0.5, 0.7):TestFunction()
new(typeof(new(Vector4, 1, 2, 3, 4)), 5, 6, 7)
```