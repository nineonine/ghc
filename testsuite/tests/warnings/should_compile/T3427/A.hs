module A where

data Foo = Foo
{-# DEPRECATED Foo "Don't use type and data constructor Foo" #-}

data Bar = Bar
{-# DEPRECATED type Bar "Don't use type Bar" #-}

data Baz = Baz
{-# DEPRECATED data Baz "Don't use data constructor Baz" #-}
