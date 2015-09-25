-- | Bindings for common class operations, such as copy construction.
module Foreign.Cppop.Generator.Spec.ClassFeature (
  ClassFeature (..),
  IteratorMutability (..),
  classAddFeatures,
  ) where

import Data.Maybe (catMaybes)
import Foreign.Cppop.Generator.Spec

-- | Sets of functionality that can be stamped onto a class with
-- 'classAddFeatures'.
data ClassFeature =
    Assignable
    -- ^ Provides the assignment operator, @Foo& Foo::operator=(const Foo&)@.
  | Comparable
    -- ^ Provides operators @<@, @<=@, @>@, @>=@, for example @bool
    -- Foo::operator<(const Foo&)@.  This feature does not automatically include
    -- 'Equatable'.
  | Copyable
    -- ^ Provides copy construction, @Foo::Foo(const Foo&)@.
  | Equatable
    -- ^ Provides @operator==@ and @operator!=@, for example @bool
    -- Foo::operator==(const Foo&)@.
  | TrivialIterator IteratorMutability Type
    -- ^ An STL trivial iterator.  Includes 'Assignable' and 'Copyable'.
    -- Provides default construction, dereferencing, and if mutable, then
    -- assignment.
  | ForwardIterator IteratorMutability Type
    -- ^ An STL forward iterator.  Includes 'TrivialIterator' and provides
    -- pre-increment.
  | BidirectionalIterator IteratorMutability Type
    -- ^ An STL bidirectional iterator.  Includes 'ForwardIterator' and provides
    -- pre-decrement.
  | RandomIterator IteratorMutability Type Type
    -- ^ An STL random-access iterator.  Includes 'BidirectionalIterator' and
    -- provides arithmetic and array access.

data IteratorMutability = Constant | Mutable

instance HasTVars ClassFeature where
  substTVar var val feature = case feature of
    Assignable -> feature
    Comparable -> feature
    Copyable -> feature
    Equatable -> feature
    TrivialIterator mutable valueType -> TrivialIterator mutable $ subst valueType
    ForwardIterator mutable valueType -> ForwardIterator mutable $ subst valueType
    BidirectionalIterator mutable valueType -> BidirectionalIterator mutable $ subst valueType
    RandomIterator mutable valueType distanceType ->
      RandomIterator mutable (subst valueType) distanceType
    where subst = substTVar var val

featureContents :: ClassFeature -> Class -> ([Ctor], [Method], Reqs)
featureContents feature cls = case feature of
  Assignable -> assignableContents cls
  Comparable -> comparableContents cls
  Copyable -> copyableContents cls
  Equatable -> equatableContents cls
  TrivialIterator mutable valueType -> trivialIteratorContents mutable cls valueType
  ForwardIterator mutable valueType -> forwardIteratorContents mutable cls valueType
  BidirectionalIterator mutable valueType -> bidirectionalIteratorContents mutable cls valueType
  RandomIterator mutable valueType distanceType ->
    randomIteratorContents mutable cls valueType distanceType

assignableContents :: Class -> ([Ctor], [Method], Reqs)
assignableContents cls =
  ([],
   [ mkMethod OpAssign [TRef $ TConst $ TObj cls] $ TRef $ TObj cls
   ],
   mempty)

comparableContents :: Class -> ([Ctor], [Method], Reqs)
comparableContents cls =
  ([],
   [ mkConstMethod OpLt [TRef $ TConst $ TObj cls] TBool
   , mkConstMethod OpLe [TRef $ TConst $ TObj cls] TBool
   , mkConstMethod OpGt [TRef $ TConst $ TObj cls] TBool
   , mkConstMethod OpGe [TRef $ TConst $ TObj cls] TBool
   ],
   mempty)

copyableContents :: Class -> ([Ctor], [Method], Reqs)
copyableContents cls =
  ([ mkCtor "newCopy" [TRef $ TConst $ TObj cls]
   ],
   [],
   mempty)

equatableContents :: Class -> ([Ctor], [Method], Reqs)
equatableContents cls =
  ([],
   [ mkConstMethod OpEq [TRef $ TConst $ TObj cls] TBool
   , mkConstMethod OpNe [TRef $ TConst $ TObj cls] TBool
   ],
   mempty)

trivialIteratorContents :: IteratorMutability -> Class -> Type -> ([Ctor], [Method], Reqs)
trivialIteratorContents mutable cls valueType =
  mconcat
  [ assignableContents cls
  , copyableContents cls
  , ([ mkCtor "new" []
     ],
     catMaybes
     [ Just $ mkConstMethod OpDeref [] valueType
     , case mutable of
       Constant -> Nothing
       Mutable -> Just $ makeFnMethod (ident2 "cppop" "iterator" "put") "put"
                  MNormal Nonpure [TPtr $ TObj cls, valueType] TVoid
     ],
     case mutable of
       Constant -> mempty
       Mutable -> reqInclude $ includeStd "cppop/iterator.hpp")
  ]

forwardIteratorContents :: IteratorMutability -> Class -> Type -> ([Ctor], [Method], Reqs)
forwardIteratorContents mutable cls valueType =
  trivialIteratorContents mutable cls valueType `mappend`
  ([],
   [ mkMethod OpIncPre [] $ TRef $ TObj cls
   ],
   mempty)

bidirectionalIteratorContents :: IteratorMutability -> Class -> Type -> ([Ctor], [Method], Reqs)
bidirectionalIteratorContents mutable cls valueType =
  forwardIteratorContents mutable cls valueType `mappend`
  ([],
   [ mkMethod OpDecPre [] $ TRef $ TObj cls
   ],
   mempty)

randomIteratorContents :: IteratorMutability -> Class -> Type -> Type -> ([Ctor], [Method], Reqs)
randomIteratorContents mutable cls valueType distanceType =
  bidirectionalIteratorContents mutable cls valueType `mappend`
  ([],
   catMaybes
   [ Just $ mkMethod OpAdd [distanceType] $ TObjToHeap cls
   , Just $ mkMethod OpAddAssign [distanceType] $ TRef $ TObj cls
   , Just $ mkMethod OpSubtract [distanceType] $ TObjToHeap cls
   , Just $ mkMethod' OpSubtract "difference" [TObj cls] distanceType
   , Just $ mkMethod OpSubtractAssign [distanceType] $ TRef $ TObj cls
   , Just $ mkMethod' OpArray "at" [distanceType] valueType
   , case mutable of
      Mutable -> Just $ mkMethod' OpArray "atRef" [distanceType] $ TRef valueType
      Constant -> Nothing
   ],
   mempty)

-- | Adds the contents of a feature to a class.  Does not check for overlap with
-- existing class contents.
classAddFeatures :: [ClassFeature] -> Class -> Class
classAddFeatures features cls =
  foldr (\feature cls' ->
          let (ctors, methods, reqs) = featureContents feature cls'
          in addUseReqs reqs $
             classAddCtors ctors $
             classAddMethods methods cls')
        cls
        features

classAddCtors :: [Ctor] -> Class -> Class
classAddCtors ctors cls =
  if null ctors then cls else cls { classCtors = classCtors cls ++ ctors }

classAddMethods :: [Method] -> Class -> Class
classAddMethods methods cls =
  if null methods then cls else cls { classMethods = classMethods cls ++ methods }