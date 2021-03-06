-- This file is part of Hoppy.
--
-- Copyright 2015-2017 Bryan Gardiner <bog@khumba.net>
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU Affero General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Affero General Public License for more details.
--
-- You should have received a copy of the GNU Affero General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

{-# OPTIONS_GHC -fno-warn-unused-imports #-}

-- | The Hoppy User's Guide
module Foreign.Hoppy.Documentation.UsersGuide (
  -- * Overview
  -- $overview

  -- * Getting started
  -- $getting-started

  -- ** Project setup
  -- $getting-started-project-setup

  -- ** Concepts
  -- $getting-started-concepts

  -- * Generators
  -- $generators

  -- ** C++
  -- $generators-cpp

  -- *** Module structure
  -- $generators-cpp-module-structure

  -- *** Object passing
  -- $generators-cpp-object-passing

  -- *** Callbacks
  -- $generators-cpp-callbacks

  -- ** Haskell
  -- $generators-hs

  -- *** Module structure
  -- $generators-hs-module-structure

  -- **** Variable exports
  -- $generators-hs-module-structure-variables

  -- **** Enum exports
  -- $generators-hs-module-structure-enums

  -- **** Bitspace exports
  -- $generators-hs-module-structure-bitspaces

  -- **** Function exports
  -- $generators-hs-module-structure-functions

  -- **** Callback exports
  -- $generators-hs-module-structure-callbacks

  -- **** Class exports
  -- $generators-hs-module-structure-classes

  -- *** Module dependencies
  -- $generators-hs-module-dependencies

  -- *** Object passing
  -- $generators-hs-object-passing

  -- *** Exceptions
  -- $generators-hs-exceptions
  ) where

import Data.Bits (Bits)
import Foreign.C (CInt)
import Foreign.Hoppy.Generator.Language.Haskell
import Foreign.Hoppy.Generator.Main
import Foreign.Hoppy.Generator.Spec
import Foreign.Hoppy.Generator.Types
import Foreign.Hoppy.Generator.Version
import Foreign.Hoppy.Runtime
import Foreign.Ptr (FunPtr, Ptr)
import Language.Haskell.Syntax (HsType)
import System.IO.Unsafe (unsafePerformIO)

{- $overview

Hoppy is a foreign function interface (FFI) generator for interfacing Haskell
with C++.  It lets developers specify C++ interfaces in pure Haskell, and
generates code to expose that functionality to Haskell.  Hoppy is made up of a
few different packages that provide interface definition data structures and
code generators, some runtime support for Haskell bindings, and interface
definitions for the C++ standard library.

Bindings using Hoppy have three parts:

- A Haskell generator program (in @\/generator@) that knows the interface
definition and generates code for the next two parts.

- A C++ library (in @\/cpp@) that gets compiled into a shared object containing
the C++ half of the bindings.

- A Haskell library (in @\/hs@) that links against the C++ library and exposes
the bindings.

The path names are suggested subdirectories of a project, and are used in this
document, but are not required.  Only the latter two items need to be packaged
and distributed to users of the binding (plus Hoppy itself which is a dependency
of the generated bindings).

-}
{- $getting-started

This section is for getting out of the gate running.

-}
{- $getting-started-project-setup

To bind to a C++ library, first the binding author writes a generator program
(@\/generator@) in Haskell.  This program should define the complete C++
interface that is to be exposed.  The binding author also writes a @Main.hs@
file for invoking the generator (usually deferring to
"Foreign.Hoppy.Generator.Main").  If necessary, she should also write wrappers
for C++ things that she doesn't want to expose directly (in @\/cpp@).

Then, her build process should perform the following steps:

1. Compile the generator (@\/generator@).

2. Run the generator to create the C++ and Haskell sides of the bindings in
@\/cpp@ and @\/hs\/src@ respectively.  See the documentation for 'run' for how
to invoke a generator.

3. Compile the C++ side of the bindings into a shared object.  Make sure to
compile with the version of the C++ standard that matches what the generator was
run with (see 'activeCppVersion').

4. Compile the Haskell side of the bindings, linking with the C++ library.

For this last step, the @.cabal@ file in @\/hs@ should have

> extra-libraries: foo

to link against a shared object @libfoo.so@.  If this library is not on the
system's library search path, then she will need to specify
@--extra-lib-dirs=...\/cpp@ to the @cabal configure@ for @\/hs@.

The unit tests provide some simple examples of this setup.

-}
{- $getting-started-concepts

A complete C++ API is specified using Haskell data structures in
"Foreign.Hoppy.Generator.Spec".  At the top level is the 'Interface' type.  An
interface contains 'Module's which correspond to a portion of functionality of
the interface (collections of classes, functions, files, etc.).  Functionality
can be grouped arbitrarily into modules and doesn't have to follow the structure
of existing C++ files.  Modules contain 'Export's which refer to concrete things
that provide bindings.  Binding definitions take advantage of Haskell's
laziness, and can be highly circular, a simple case being a class that includes
a method that makes use of the class in its parameter or return types.

Each export has an /external name/ that uniquely identifies it within an
interface.  This name can be different from the name of the C++ entity the
export is referring to.  An external name is munged by the code generators and
must be a valid identifier in all languages a set of bindings will use, so it is
restricted to characters in the range @[a-zA-Z0-9_]@, and must start with an
alphabetic character.  Character case in external names will be preserved as
much as possible in generated code, although case conversions are sometimes
necessary (e.g. Haskell requiring identifiers to begin with upper or lower case
characters).

C++ bindings for exportable things usually need @#include@s in order to access
those things.  This is done with 'Include' and 'Reqs'.  All exportable things
have an instance of 'HasReqs' and 'addReqIncludes' can be used to add includes.

C++ identifiers are represented by the 'Identifier' data type and support basic
template syntax (no metaprogramming).

All C++ types are represented with the 'Type' data type, values of which are in
the "Foreign.Hoppy.Generator.Types" module.  This includes primitive numeric
types, object types, function types, @void@, the const qualifier, etc.  When
passing values back and forth between C++ and Haskell, generally, primitive
types are converted to equivalent types on both ends, and pointer types in C++
are represented by corresponding pointer types in Haskell.

For numbers, Haskell declares a number of numeric types in "Foreign.C" for
interfacing with C directly.  Hoppy maps C++ numbers to these types, with the
exception of `bool`, `int`, `float`, and `double`, which map to their native
Haskell equivalents instead ('Bool', 'Int', 'Float', 'Double').

Raw object types (not pointers or references, just the by-value object types,
i.e. 'objT') are treated differently.  When an object is taken or returned by
value, this typically indicates a lightweight object that is easy to copy, so
Hoppy will attempt to convert the C++ object to a native Haskell object, if a
Haskell type is defined for the class.  Other options are available, such as
having objects be handed off to a foreign garbage collector.  See
'ClassConversion' for more on object conversions.

Internally, only C types are exchanged over the gateway, since these are what is
common to both languages.  Conversions are performed on both sides of the
gateway.  In most cases, the C++, C, and Haskell types all have equivalent
representation no conversion is necessary.

-}
{- $generators

This section describes the behaviour of the code generators.  The code
generators live at @Foreign.Hoppy.Generator.Language.\<language>@.  The
top-level module for a language is internal to Hoppy and contains the bulk of
the generator.  @General@ submodules expose functionality that can control
generator behaviour.

-}
{- $generators-cpp

The C++ code generator generates C++ bindings that other languages' bindings
will link against.  This generator lives in
"Foreign.Hoppy.Generator.Language.Cpp", with internal parts in
"Foreign.Hoppy.Generator.Language.Cpp.Internal".

-}
{- $generators-cpp-module-structure

Generated modules consist of a source and a header file.  The source file
contains all of the bindings for foreign languages to make use of.  The header
file contains things that may be depended on from other generated modules.
Currently this consists only of generated callback classes.

Cycles between generated C++ modules are not supported.  This can currently only
happen because of @#include@ cycles involving callbacks, since callbacks are the
only 'Export's that can be referenced by other generated C++ code.  Also, C++
callbacks that handle exceptions depend on the interface's exception support
module (see 'interfaceExceptionSupportModule').

-}
{- $generators-cpp-object-passing

@
'ptrT' :: 'Type' -> 'Type'
'refT' :: 'Type' -> 'Type'
'objT' :: 'Class' -> 'Type'
'constT' :: 'Type' -> 'Type'
@

We consider all of the following cases as passing an object, both into and out
of C++, and independently, as an argument and as a return value:

1. @'objT' _@
2. @'refT' ('constT' ('objT' _))@
3. @'refT' ('objT' _)@
4. @'ptrT' ('constT' ('objT' _))@
5. @'ptrT' ('objT' _)@

The first is equivalent to @'constT' ('objT' _)@.  When passing an argument from
a foreign language to C++, the first two are equivalent, and it's recommended to
use the first, shorter form (@T@ and @const T&@ are functionally equivalent in
C++, and are the same as far as what values foreign bindings will accept).

When passing any of the above types as an argument in either direction, an
object is passed between C++ and a foreign language via a pointer.  Cases 1, 2,
and 4 are passed as const pointers.  For a foreign language passing a @'objT' _@
to C++, this means converting a foreign value to a temporary C++ object.
Passing a @'objT' _@ argument into or out of C++, the caller always owns the
object.

When returning an object, again, pointers are always what is passed across the
language boundary in either direction.  Returning a @'objT' _@ transfers
ownership: a C++ function returning a @'objT' _@ will copy the object to the
heap, and return a pointer to the object which the caller owns; a callback
returning a @'objT' _@ will internally create a C++ object from a foreign value,
and hand that object off to the C++ side (which will return it and free the
temporary).

Object lifetimes can be managed by a foreign language's garbage collector.
'toGcT' is a special type that is only allowed in certain forms, and only when
passing a value from C++ to a foreign language (i.e. returning from a C++
function, or C++ invoking a foreign callback), to put the object under the
collector's management.  Only object types are allowed:

1. @'toGcT' ('objT' cls)@
2. @'toGcT' ('refT' ('constT' ('objT' cls)))@
3. @'toGcT' ('refT' ('objT' cls))@
4. @'toGcT' ('ptrT' ('constT' ('objT' cls)))@
5. @'toGcT' ('ptrT' ('objT' cls))@

Cases 2-5 are straightforward: the existing object is given to the collector.
Case 1 without the 'toGcT' would cause the object to be converted, but instead
here the (temporary) object gets copied to the heap, and a managed pointer to
the heap object is returned.  Case 1 is useful when you want to pass a handle
that has a non-trivial C++ representation (so you don't define a conversion for
it), but it's still a temporary that you don't want users to have to delete
manually.

Objects are always managed manually unless given to a garbage collector.  In
particular, constructors always return unmanaged pointers.  When a managed
pointer is passed into C++, that it is managed is lost in the FFI conversion,
and if this pointer is then passed back into the foreign language, it will
arrive in an unmanaged state (although the object is still managed, and it
should not be assigned to the collector a second time).

-}
{- $generators-cpp-callbacks

> data Callback = Callback ExtName [Type] Type ...  -- Parameter and return types.
>
> callbackT :: Callback -> Type

We want to call some foreign code from C++.  There are two choices for doing so,
described below.  Declaring a callback provides support for both types of
invocation.

__Function pointer:__ Function pointers are expressed with a @'ptrT' ('fnT'
...)@ type.  Foreign runtimes' FFIs can provide a means for creating raw
function pointers directly (Haskell's does with 'FunPtr').  Hoppy provides an
optional layer that performs the necessary type conversions, but only the
foreign half of the conversions, so only C types can be used within function
pointer types (this is a limitation of speaking over a C FFI; an error is
signaled when trying to use a type that requires C\<-\>C++ conversion).  The
other downside of using function pointers is that C++ provides no lifetime
tracking, and because in general foreign code can't know how long some C++ code
is going to hold a function pointer, it's necessary to manage the lifetime of
the pointer manually.

__C++ functor:__ This is the preferred method for calling into foreign code.
This type is expressed with 'callbackT'.  It wraps the function pointer support
above in C++ functors that add automatic lifetime tracking.

Internally, we create a class G that takes a foreign function pointer and
implements @operator()@, performing the necessary conversions around invoking
the pointer.  In the event that the function pointer is dynamically allocated
(as in Haskell), then this class also ties the lifetime of the function pointer
to the lifetime of the class.  But this would cause problems for passing this
object around by value, so instead we make G non-copyable and non-assignable,
allocate our G instance on the heap, and create a second class F that holds a
@shared_ptr\<G>@ and whose @operator()@ calls through to G.

This way, the existance of the F and G objects are invisible to the foreign
language, and (for now) passing these callbacks back to the foreign language is
not supported.

When a binding is declared to take a callback type, the generated foreign side
of the binding will take a foreign function (the callback) with foreign-side
types, and use a function (Haskell: callbackName) generated for the callback
type to wrap the callback in a foreign function that does argument decoding and
return value encoding: this wrapped function will have C-side types.  The
binding will then create a G object (above) for this wrapped function (Haskell:
using callbackName'), and pass a G pointer into the C side of the binding.  The
binding will decode this C pointer by wrapping it in a temporary F object, and
passing that to the C++ function.  The C++ code is free to copy this F object as
much as it likes.  If it doesn't store a copy somewhere before returning, then
the when the temporary F object is destructed, the G object will get deleted.

-}
{- $generators-hs

The Haskell code generator lives in "Foreign.Hoppy.Generator.Language.Haskell",
with internal parts in "Foreign.Hoppy.Generator.Language.Haskell.Internal".

Central to generated Haskell bindings is the idea of type sidedness and the
'HsTypeSide' enum.  When a value is passed to or from C++, it needs to be
converted so that the receiving language knows what to do with it.  The C++ side
of bindings just exchanges C types across the language boundary and does not do
conversions, so it is up to the Haskell side to do so.  Internally, the Haskell
generator refers to types exchanged with C++ as /C-side/ types, and types the
bindings exchange with user Haskell code as /Haskell-side/ types.  These are
both Haskell types!  The terminology is overlapped a bit but generally, /type/
or /C++ type/ refers to a 'Type', and in the context of the Haskell generator,
/C-side/ or /Haskell-side/ apply to a 'HsType', calculated from a 'Type' and a
'HsTypeSide' using 'cppTypeToHsTypeAndUse'.  For many primitive C++ types, the
C-side and Haskell-side types are the same.

-}
{- $generators-hs-module-structure

The result of generating a Hoppy module is a single Haskell module that contains
bindings for everything exported from the Hoppy module.  The Haskell module name
is the concatenation of the interface's 'interfaceHaskellModuleBase' and the
module's 'moduleHaskellName'.

The contents of the module depends on the what 'Export's the module has.

-}
{- $generators-hs-module-structure-variables

A 'Variable' is exposed in Haskell as a getter function and a setter function.
For a variable with external name @foo@ with Haskell-side type @Bar@, the
following functions are created:

> foo_get :: IO Bar
> foo_set :: Bar -> IO ()

-}
{- $generators-hs-module-structure-enums

A 'CppEnum' is exposed in Haskell as an enumerable data type.  For an enum
defined as follows:

@
alignment :: 'CppEnum'
alignment =
  'makeEnum' ('ident' \"Alignment\") Nothing
  [ (0, [\"left\", \"align\"])
  , (1, [\"center\", \"align\"])
  , (2, [\"right\", \"align\"])
  ]
@

the following data type will be generated:

@
data Alignment =
    Alignment_LeftAlign
  | Alignment_CenterAlign
  | Alignment_RightAlign
@

with instances for 'Bounded', 'Enum', 'Eq', 'Ord', and 'Show'.

-}
{- $generators-hs-module-structure-bitspaces

'Bitspace's, unlike enums, materialize in Haskell using a single data
constructor and bindings for values, rather than multiple data constructors.  A
bitspace declaration such as

@
formatFlags :: 'Bitspace'
formatFlags =
  'makeBitspace' ('toExtName' \"Format\") 'intT'
  [ (1, [\"format\", \"letter\"])
  , (2, [\"format\", \"jpeg\"])
  , (4, [\"format\", \"c\"])
  ]
@

will generate the following:

@
newtype Format

instance 'Bits' Format
instance 'Bounded' Format
instance 'Eq' Format
instance 'Ord' Format
instance 'Show' Format

fromFormat :: Format -> 'CInt'

class IsFormat a where
  toFormat :: a -> Format

instance IsFormat 'CInt'

format_FormatLetter :: Format
format_FormatJpeg :: Format
format_FormatC :: Format
@

-}
{- $generators-hs-module-structure-functions

For a 'Function' export, a single Haskell function will be generated named after
the external name of the export.  The function will take the Haskell-side types
of its arguments, and return the Haskell-side type of its return type.  If the
function is 'Nonpure' then it will return a value in 'IO', otherwise it will
return a pure value using 'unsafePerformIO'.

For most 'Type's, the corresponding Haskell parameter type will be a concrete
type.  This differs for objects (and references and pointers to them), where
typeclass constraints are used to implement C++ parameter type contravariance.
See the section on Haskell object passing for more details.

-}
{- $generators-hs-module-structure-callbacks

Declared callbacks provide support for callback types ('callbackT') as well as
function pointers (@'ptrT' ('fnT' ...)@) in Haskell.

Callback types manifest directly as Haskell function types in @IO@.  Function
pointers manifest as 'FunPtr's around Haskell function types in @IO@.

No runtime support is exposed to the user for working with internal Haskell
callback types (some machinery is generated however).  For function pointer
types, a function `callbackName_newFunPtr` is exposed from the callback's module
that makes it easy to wrap anonymous functions in 'FunPtr's that perform the
Haskell side of conversions, with code like the following:

> -- Generator bindings
>
> cb_intCallback = makeCallback "IntCallback" [intT] intT
>
> f_funPtrTest = makeFn "funPtrTest" Nothing Nonpure [ptrT $ fnT [intT] intT] intT
>
> f_callbackTest = makeFn "callbackTest" Nothing Nonpure [callbackT cb_intCallback] intT

> -- Test program
>
> import Foreign.C (CInt)
> import Foreign.Hoppy.Runtime (withScopedFunPtr)
>
> -- Generated things:
> intCallback_newFunPtr :: (Int -> IO Int) -> IO (FunPtr (CInt -> IO CInt))
> funPtrTest :: FunPtr (CInt -> IO CInt) -> Int
> callbackTest :: (Int -> IO Int) -> Int
>
> -- Driver code:
> callFunPtrTest = withScopedFunPtr (intCallback_newFunPtr $ return . (* 2)) funPtrTest
> callCallbackTest = callbackTest $ return . (* 2)

-}
{- $generators-hs-module-structure-classes

'Class'es expose quite a few things to the user.  Take a simple class
definition such as:

@
compressor :: 'Class'

zipper :: 'Class'
zipper =
  'makeClass' ('ident' \"Zipper\") Nothing [compressor]
  [ 'mkCtor' \"new\" [] ]
  [ 'mkStaticMethod' \"canZip\" [] 'boolT'
  , 'mkConstMethod' \"hasZipped\" [] 'voidT'
  , 'mkMethod' \"zip\" [] 'voidT'
  ]
@

Let's focus on @zipper@.  Two data types will be generated that represent
const and non-const pointers to @Zipper@ objects:

@
data Zipper
data ZipperConst
@

Internally, these types hold 'Ptr's, and they can be converted to 'Ptr's with
'toPtr' (though this conversion is lossy for pointers managed by the garbage
collector, see the section on object passing).

Several typeclass instances are generated for both types:

- 'Eq', 'Ord', and 'Show' compare and render based on the underlying pointer
address.

- 'CppPtr' and 'Deletable' instances provide object management.

- A single @'Decodable' ('Ptr' Zipper) Zipper@ instance is generated for
converting raw 'Ptr's into object handles.  This is the opposite operation of
'toPtr'.

- If the class -- @Zipper@ in this case -- has an @operator=@ method that takes
either a @'objT' zipper@ or a @'refT' ('constT' ('objT' zipper))@, then an
instance @ZipperValue a => 'Assignable' Zipper a@ is generated to allow
assigning of general zipper-like values to @Zipper@ objects; see below for an
explanation of @ZipperValue@.  This instance is for the non-const @Zipper@ only.

There will also be some typeclasses generated, for types that represent @Zipper@
objects:

@
class ZipperValue a where
  withZipperPtr :: a -> (ZipperConst -> IO b) -> IO b

instance CompressorPtrConst a => ZipperValue a

class CompressorPtrConst a => ZipperPtrConst a where
  toZipperConst :: a -> ZipperConst

class (ZipperPtrConst a, CompressorPtr a) => ZipperPtr a where
  toZipper :: a -> Zipper

instance ZipperPtrConst ZipperConst
instance ZipperPtr Zipper
... instances required by superclasses ...
@

Ignoring the first typeclass and instance for a moment, the two @Ptr@
typeclasses represent const and non-const pointers respectively, and allow
upcasting pointer types.  The const typeclass has as superclasses the const
typeclasses for all of the C++ class's superclasses (or just 'CppPtr' if this
list is empty).  The non-const typeclass has as superclasses the non-const
typeclasses for all of the C++ class's superclasses, plus the current const
typeclass.  Instances will be generated for all of the appropriate typeclasses
for @Zipper@ and @ZipperConst@, all the way up to 'CppPtr'.

The @ZipperValue@ class represents general @Zipper@ values, of which pointers
are one type (hence the first @instance@ above).  Values of these types can be
converted to a temporary const pointer.  If @Zipper@ were to have a native
Haskell type (see 'classHaskellConversion'), then an additional instance would
be generated for that type.  This second instance in this case is overlapping,
and the above instance is overlappable.  These typeclasses allow for mixing
pointer, reference, and object types when calling C++ functions.

For downcasting, separate const and non-const typeclasses are generated with
instances for all direct and indirect superclasses of @Zipper@:

@
-- Enables downcasting from any non-const superclass of Zipper.
class ZipperSuper a where
  downToZipper :: a -> Zipper

-- Enables downcasting from any const superclass of Zipper.
class ZipperSuperConst a where
  downToZipperConst :: a -> ZipperConst

instance ZipperSuper Compressor
... instances for other non-const superclasses ...
instance ZipperSuperConst CompressorConst
... instances for other const superclasses ...
@

The downcast functions are wrappers around @dynamic_cast@, and will return a
null pointer if the argument is not a supertype of the target type.

Finally, Haskell functions are generated for all of the class's constructors and
methods.  These work much the same as function exports, but non-static methods
take a @this@ object as the first argument.  Const methods take a @ZipperValue@
on the assumption that it's safe to create a temporary C++ object from a Haskell
value if necessary to call a const method.  Non-const methods take a
@ZipperPtr@, since it's potentially a mistake to perform side-effects on a
temporary object that is thrown away immediately.

@
zipper_new :: 'IO' Zipper
zipper_canZip :: 'IO' 'Bool'
zipper_hasZipped :: ZipperValue this => this -> 'IO' 'Bool'
zipper_zip :: ZipperPtr this => this -> 'IO' 'Bool'
@

-}
{- $generators-hs-module-dependencies

While generated C++ modules get their objects from @#include@s of underlying
headers and only depend on each other in the case of callbacks, Haskell modules
depend on each other any time something in one references something in another
(somewhat mirroring the dependency graph of the binding definitions), so cycles
are much more common (for example, when a C++ interface uses a forward class
declaration to break an @#include@ cycle).  Fortunately, GHC supports dependency
cycles, so Hoppy automatically detects and breaks cycles with the use of
@.hs-boot@ files.  The boot files contain everything that could be used from
another generated module, for example class casting functions needed to coerce
pointers to the right type for a foreign call, or enum data declarations.  The
result of this cycle breaking is deterministic: for each non-trivial strongly
connected component in the module dependency graph, @.hs-boot@ files are
generated for all modules, and all @.hs@ files' dependencies within the SCC
import @.hs-boot@ files.

-}
{- $generators-hs-object-passing

All of the comments about argument passing for the C++ generator apply here.
The following types are used for passing arguments from Haskell to C++:

>  C++ type   | Pass over FFI | HsCSide  | HsHsSide
> ------------+---------------+----------+-----------------
>  Foo        | Foo const*    | FooConst | FooValue a => a
>  Foo const& | Foo const*    | FooConst | FooValue a => a
>  Foo&       | Foo*          | Foo      | FooPtr a => a
>  Foo const* | Foo const*    | FooConst | FooValue a => a
>  Foo*       | Foo*          | Foo      | FooPtr a => a

@FooPtr@ contains pointers to nonconst @Foo@ (and all subclasses).  @FooValue@
contains pointers to const and nonconst @Foo@ (and all subclasses), as well as
the convertible Haskell type, if there is one.  The rationale is that @FooValue@
is used where the callee will not modify the argument, so both a const pointer
to an existing object, and a fresh const pointer to a temporary on the case of
passing a @Foo@, are fine.  Because functions taking @Foo&@ and @Foo*@ may
modify their argument, we disallow passing a temporary converted from a Haskell
value implicitly; 'withCppObj' can be used for this.

For values returned from C++, and for arguments and return values in callbacks,
the 'HsCSide' column above is the exposed type; polymorphism as in the
'HsHsSide' column is not provided.

Object pointer types in Haskell hide whether they are managed (garbage
collected) or unmanaged pointers in their runtime representation.  The APIs that
bindings expose to Haskell users should generally not require them to be
concerned about object lifetimes, and also having separate data types for
managed pointers would balloon the size of bindings.  Unmanaged objects can be
converted to managed objects with 'toGc'; after calling this function, the value
it returns should always be used in place of any existing pointers.

-}
{- $generators-hs-exceptions

C++ exceptions can caught and thrown in Haskell.  C++ entities that deal with
exceptions need to be marked as such, for Hoppy to generate the support code for
them.  To work with exceptions at all, you need to pick one of your Hoppy
modules to contain some runtime support code, using
'interfaceSetExceptionSupportModule'.  C++ functions that throw need to be
marked with the specific exceptions that they throw, using 'handleExceptions'.
Callbacks that want to be able to throw need to be marked with
'callbackSetThrows', after which they are allowed to throw any exception classes
defined in the interface.  Exception handling in both directions can also be set
up at the module and interface levels using 'handleExceptions',
'interfaceSetCallbacksThrow', and 'moduleSetCallbacksThrow'.

Classes can be marked as being exception classes with 'classMakeException'.
Exception classes need to be copyable, so make sure to define a copy constructor
(use 'Copyable').

C++ exceptions in Haskell are handled with 'throwCpp' and 'catchCpp'.  While
they use Haskell exceptions under the hood, do not use 'throw' and 'catch' to
work with them; this may leak C++ objects.

Catching a wildcard (i.e. @catch (...)@) is supported, but no information is
available about the caught value.

Implementation-wise, an in-flight C++ exception in Haskell always owns the
object (which is on the heap).  An exception coming from C++ into Haskell (it's
a heap temporary) will be given to the garbage collector.  Hence, for ease of
use, caught exceptions should always be garbage-collected.  Also, when throwing
from Haskell, throwing will always take ownership of the object.  If 'throwCpp'
gets a non-GCed object, then it will be given to the garbage collector; and then
the exception will be thrown as a Haskell exception.  If the exception
propagates out to a callback and back into C++, then a temporary non-GCed copy
will be passed over the gateway, and rethrown as a value object on the C++ side.

In the above strategy, when throwing an exception from Haskell that propagates
to C++, it is wasteful to make the thrown object GCed, just to have to create a
non-GCed copy.  So when we throw from Haskell, we don't actually assign to the
garbage collector immediately (if it's not already); instead, we delay the
'toGc' call until 'catchCpp'.

-}
