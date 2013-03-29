module Data.API.Parse
    ( parseAPI
    , test_p
    ) where

import           Data.API.Types
import           Data.API.Scan
import           Text.Parsec
import           Text.Parsec.Pos
import qualified Data.CaseInsensitive       as CI
import           Control.Applicative((<$>))
import           Control.Monad

    
    

parseAPI :: String -> API
parseAPI inp =
    case parse api_p "" $ scan inp of
      Left  pe  -> error $ show pe
      Right api -> api  

test_p :: Parse a -> String -> a
test_p psr inp =
    case parse psr "" $ scan inp of
      Left  pe -> error $ show pe
      Right y  -> y  


{-
test :: IO () 
test =
 do cts <- readFile "test.txt"
    print $ scan cts
    print $ parseAPI cts
-}


type Parse a = Parsec [PToken] () a

api_p :: Parse API
api_p = 
    many $ kw_p Semi >> 
        (ThNode <$> node_p <|> ThComment <$> comments_p)

node_p :: Parse APINode
node_p =
 do pre <- prefix_p
    kw_p ColCol
    con <- type_name_p
    cts <- comments_p
    kw_p Equals
    spc <- spec_p
    cnv <- with_p
    vrn <- version_p
    vlg <- comments_p
    return $ APINode con cts pre spc cnv vrn vlg

spec_p :: Parse Spec
spec_p =
    SpNewtype . SpecNewtype <$> basic_p 
        <|> SpRecord  <$> record_p 
        <|> SpUnion   <$> union_p
        <|> SpEnum    <$> enum_p
        <|> SpSynonym <$> type_p

record_p :: Parse SpecRecord
record_p =
 do kw_p Record
    SpecRecord <$> fields_p False

union_p :: Parse SpecUnion
union_p =
 do kw_p Union
    SpecUnion <$> fields_p True

enum_p :: Parse SpecEnum
enum_p = 
 do fn  <- field_name_p
    fns <- many $ kw_p Bar >> field_name_p
    return $ SpecEnum $ fn:fns

fields_p :: Bool -> Parse ([(FieldName,(APIType,MDComment))])
fields_p is_u = many $
     do when is_u $
            kw_p Bar
        fnm <- field_name_p
        kw_p Colon
        typ <- type_p
        cmt <- comments_p
        return $ (fnm,(typ,cmt))

with_p :: Parse Conversion
with_p = optionMaybe $
 do kw_p With
    inj <- field_name_p
    kw_p Comma
    prj <- field_name_p
    return (inj,prj)

version_p :: Parse Vrn
version_p = p <|> return 1
  where
    p = kw_p Version >> Vrn <$> integer_p

type_p :: Parse APIType
type_p = list_p <|> maybe_p <|> TyName <$> type_name_p <|> TyBasic <$> basic_p

maybe_p :: Parse APIType
maybe_p =
 do kw_p Query
    typ <- type_p
    return $ TyMaybe typ

list_p :: Parse APIType
list_p = 
 do kw_p Bra
    typ <- type_p
    kw_p Ket
    return $ TyList typ

basic_p :: Parse BasicType
basic_p = 
    const BTstring <$> kw_p String        <|>
    const BTbinary <$> kw_p Binary        <|>
    const BTbool   <$> kw_p Boolean       <|>
    const BTint    <$> kw_p Integer

comments_p :: Parse MDComment
comments_p = unlines <$> many comment_p

comment_p :: Parse MDComment
comment_p = tok_p p
  where
    p (Comment cmt) = Just cmt
    p _             = Nothing 

prefix_p :: Parse Prefix
prefix_p = tok_p p
  where
    p (VarIden var) = is_prefix var
    p _             = Nothing

type_name_p :: Parse TypeName 
type_name_p = tok_p p
  where
    p (TypeIden tid) = Just $ TypeName tid
    p _              = Nothing

field_name_p :: Parse FieldName 
field_name_p = tok_p p
  where
    p (VarIden var) = Just $ FieldName var
    p _             = Nothing

integer_p :: Parse Int
integer_p = tok_p p
  where
    p (Intg i) = Just i
    p _        = Nothing

kw_p :: Token -> Parse () 
kw_p tk = tok_p p
  where
    p tk' =
        case tk==tk' of
          True  -> Just ()
          False -> Nothing  

tok_p :: (Token->Maybe a) -> Parse a
tok_p f = token pretty position $ f . snd

pretty :: PToken -> String
pretty = show

position :: PToken -> SourcePos
position (AlexPn _ ln cl,_) = setSourceLine (setSourceColumn pos cl) ln

is_prefix :: String -> Maybe Prefix
is_prefix var = Just $ CI.mk var

pos :: SourcePos
pos = initialPos ""
