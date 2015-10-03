{-# OPTIONS_GHC -Wall #-}
module Format where

import Elm.Utils ((|>))
import Box

import AST.V0_15
import qualified AST.Declaration
import qualified AST.Expression
import qualified AST.Literal as L
import qualified AST.Module
import qualified AST.Module.Name as MN
import qualified AST.Pattern
import qualified AST.Type
import qualified AST.Variable
import qualified Data.List as List
import qualified Reporting.Annotation as RA


formatModule :: AST.Module.Module -> Box
formatModule modu =
    vbox
        [ hbox
            [ text "module "
            , formatName $ AST.Module.name modu
            , text " where"
            ]
            |> margin 1
        , case AST.Module.imports modu of
            [] ->
                empty
            imports ->
                vbox (map formatImport imports)
                |> margin 2
        , vbox (map formatDeclaration $ AST.Module.body modu)
        ]


formatName :: MN.Canonical -> Box
formatName name = formatRawName $ MN._module name


formatRawName :: MN.Raw -> Box
formatRawName name =
    text (List.intercalate "." name)


formatImport :: AST.Module.UserImport -> Box
formatImport aimport =
    case RA.drop aimport of
        (name,method) ->
            hbox
                [ text "import "
                , formatRawName name
                , as
                , exposing
                ]
            where
                as =
                    if (AST.Module.alias method) == (Just $ List.intercalate "." name)
                        then empty
                    else
                        case AST.Module.alias method of
                            Nothing -> text "<nothing>"
                            Just alias -> text $ " as " ++ alias
                exposing =
                    case AST.Module.exposedVars method of
                        AST.Variable.Listing [] False -> empty
                        AST.Variable.Listing [] True -> text " exposing (..)"
                        AST.Variable.Listing vars False ->
                            hbox
                                [ text " exposing ("
                                , hjoin (text ", ") (map formatVarValue vars)
                                , text ")"
                                ]
                        AST.Variable.Listing _ True -> text "<NOT POSSIBLE?>"


formatVarValue :: AST.Variable.Value -> Box
formatVarValue aval =
    case aval of
        AST.Variable.Value val -> formatVar val
        AST.Variable.Alias _ -> text "<alias>"
        AST.Variable.Union _ _ -> text "<union>"


formatDeclaration :: AST.Declaration.Decl -> Box
formatDeclaration decl =
    case decl of
        AST.Declaration.Comment _ -> text "<comment>"
        AST.Declaration.Decl adecl ->
            case RA.drop adecl of
                AST.Declaration.Definition def -> formatDefinition def
                AST.Declaration.Datatype _ _ _ -> text "<datatype>"
                AST.Declaration.TypeAlias _ _ _ -> text "<typealias>"
                AST.Declaration.PortAnnotation _ _ -> text "<port annotation>"
                AST.Declaration.PortDefinition _ _ -> text "<port definition>"
                AST.Declaration.Fixity _ _ _ -> text "<fixity>"


formatDefinition :: AST.Expression.Def -> Box
formatDefinition adef =
    case RA.drop adef of
        AST.Expression.Definition pattern expr ->
            vbox
                [ hbox
                    [ formatPattern pattern
                    , text " ="
                    ]
                , formatExpression expr
                    |> indent
                    |> margin 2
                ]
        AST.Expression.TypeAnnotation var typ ->
            hbox
                [ formatVar var
                , text " : "
                , formatType typ
                ]


formatPattern :: AST.Pattern.Pattern -> Box
formatPattern apattern =
    case RA.drop apattern of
        AST.Pattern.Data _ _ -> text "<pattern data>"
        AST.Pattern.Tuple _ -> text "<pattern tuple>"
        AST.Pattern.Record _ -> text "<record>"
        AST.Pattern.Alias _ _ -> text "<alias>"
        AST.Pattern.Var var -> formatVar var
        AST.Pattern.Anything -> text "<anything>"
        AST.Pattern.Literal _ -> text "<literal>"


formatExpression :: AST.Expression.Expr -> Box
formatExpression aexpr =
    case RA.drop aexpr of
        AST.Expression.Literal lit -> formatCommented formatLiteral lit
        AST.Expression.Var v ->
            formatVar v
        AST.Expression.Range _ _ -> text "<range>"
        AST.Expression.ExplicitList _ -> text "<list>"
        AST.Expression.Binop op l r ->
            hbox
                [ formatExpression l
                , hspace 1
                , formatInfixVar op
                , hspace 1
                , formatExpression r
                ]
        AST.Expression.Lambda pat expr -> -- TODO: not tested
            hbox
                [ text "(\\"
                , formatPattern pat
                , text " -> "
                , formatExpression expr
                , text ")"
                ]
        AST.Expression.App l r ->
            hbox
                [ formatExpression l
                , hspace 1
                , formatExpression r
                ]
        AST.Expression.If _ _ -> text "<if>"
        AST.Expression.Let _ _ -> text "<let>"
        AST.Expression.Case _ _ -> text "<case>"
        AST.Expression.Data _ _ -> text "<expression data>"
        AST.Expression.Tuple exprs ->
            hbox $
                [ text "(" ]
                ++ (List.map formatExpression exprs |> List.intersperse (text ", ")) ++
                [ text ")" ]
        AST.Expression.Access _ _ -> text "<access>"
        AST.Expression.Update _ _ -> text "<update>"
        AST.Expression.Record _ -> text "<record>"
        AST.Expression.Port _ -> text "<port>"
        AST.Expression.GLShader _ _ _ -> text "<glshader>"


formatCommented :: (a -> Box) -> Commented a -> Box
formatCommented format commented =
    case commented of
        Commented comments inner ->
            hbox
                [ hbox (map formatComment comments)
                , format inner
                ]


formatComment :: String -> Box
formatComment comment =
    text $ "{- " ++ comment ++ " -} "


formatLiteral :: L.Literal -> Box
formatLiteral lit =
    case lit of
        L.IntNum i ->
            text $ show i
        L.FloatNum f ->
            text $ show f
        L.Chr c ->
            text ['\'', c, '\''] -- TODO: escape specials
        L.Str s ->
            text $ "\"" ++ s ++ "\"" -- TODO: escaping
        L.Boolean True ->
            text "True"
        L.Boolean False ->
            text "False" -- TODO: not tested


formatType :: AST.Type.Type -> Box
formatType atype =
    case RA.drop atype of
        AST.Type.RLambda _ _ -> text "<lambda type>"
        AST.Type.RVar var -> text var -- TODO: not tested
        AST.Type.RType var -> formatVar var
        AST.Type.RApp _ _ -> text "<app>"
        AST.Type.RTuple _ -> text "<tuple>"
        AST.Type.RRecord _ _ -> text "<record>"


formatVar :: AST.Variable.Ref -> Box
formatVar var =
    case var of
        AST.Variable.VarRef name ->
            text name
        AST.Variable.OpRef name ->
            text $ "(" ++ name ++ ")"
        AST.Variable.WildcardRef ->
            text "_" -- TODO: not tested


formatInfixVar :: AST.Variable.Ref -> Box
formatInfixVar var =
    case var of
        AST.Variable.VarRef name ->
            text $ "`" ++ name ++ "`" -- TODO: not tested
        AST.Variable.OpRef name ->
            text name
        AST.Variable.WildcardRef ->
            text "_" -- TODO: should never happen
