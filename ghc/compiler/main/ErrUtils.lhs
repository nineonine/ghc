%
% (c) The AQUA Project, Glasgow University, 1994-1998
%
\section[ErrsUtils]{Utilities for error reporting}

\begin{code}
module ErrUtils (
	Message, mkLocMessage, printError,

	ErrMsg, WarnMsg,
	Messages, errorsFound, emptyMessages,
	mkErrMsg, mkWarnMsg,
	printErrorsAndWarnings, pprBagOfErrors, pprBagOfWarnings,

	ghcExit,
	doIfSet, doIfSet_dyn, 
	dumpIfSet, dumpIfSet_core, dumpIfSet_dyn, dumpIfSet_dyn_or, mkDumpDoc,
	showPass
    ) where

#include "HsVersions.h"

import Bag		( Bag, bagToList, isEmptyBag, emptyBag )
import SrcLoc		( SrcSpan )
import Util		( sortLt )
import Outputable
import qualified Pretty
import SrcLoc		( srcSpanStart )
import CmdLineOpts	( DynFlags(..), DynFlag(..), dopt,
			  opt_ErrorSpans )

import List             ( replicate )
import System		( ExitCode(..), exitWith )
import IO		( hPutStr, stderr, stdout )
\end{code}

Basic error messages: just render a message with a source location.

\begin{code}
type Message = SDoc

mkLocMessage :: SrcSpan -> Message -> Message
mkLocMessage locn msg
  | opt_ErrorSpans = hang (ppr locn <> colon) 4 msg
  | otherwise      = hang (ppr (srcSpanStart locn) <> colon) 4 msg
  -- always print the location, even if it is unhelpful.  Error messages
  -- are supposed to be in a standard format, and one without a location
  -- would look strange.  Better to say explicitly "<no location info>".

printError :: SrcSpan -> Message -> IO ()
printError span msg = printErrs (mkLocMessage span msg $ defaultErrStyle)
\end{code}

Collecting up messages for later ordering and printing.

\begin{code}
data ErrMsg = ErrMsg SrcSpan Pretty.Doc
	-- The SrcSpan is used for sorting errors into line-number order
	-- NB  Pretty.Doc not SDoc: we deal with the printing style (in ptic 
	-- whether to qualify an External Name) at the error occurrence

type WarnMsg = ErrMsg

-- These two are used heavily by renamer/typechecker.
--  Be refined about qualification, return an ErrMsg
mkErrMsg :: SrcSpan -> PrintUnqualified -> Message -> ErrMsg
mkErrMsg locn print_unqual msg
  = ErrMsg locn (mkLocMessage locn msg $ mkErrStyle print_unqual)

mkWarnMsg :: SrcSpan -> PrintUnqualified -> Message -> WarnMsg
mkWarnMsg = mkErrMsg

type Messages = (Bag WarnMsg, Bag ErrMsg)

emptyMessages :: Messages
emptyMessages = (emptyBag, emptyBag)

errorsFound :: DynFlags -> Messages -> Bool
-- The dyn-flags are used to see if the user has specified
-- -Werorr, which says that warnings should be fatal
errorsFound dflags (warns, errs) 
  | dopt Opt_WarnIsError dflags = not (isEmptyBag errs) || not (isEmptyBag warns)
  | otherwise  		        = not (isEmptyBag errs)

printErrorsAndWarnings :: Messages -> IO ()
	-- Don't print any warnings if there are errors
printErrorsAndWarnings (warns, errs)
  | no_errs && no_warns  = return ()
  | no_errs		 = printErrs (pprBagOfWarnings warns)
  | otherwise		 = printErrs (pprBagOfErrors   errs)
  where
    no_warns = isEmptyBag warns
    no_errs  = isEmptyBag errs

pprBagOfErrors :: Bag ErrMsg -> Pretty.Doc
pprBagOfErrors bag_of_errors
  = Pretty.vcat [Pretty.text "" Pretty.$$ e | ErrMsg _ e <- sorted_errs ]
    where
      bag_ls	  = bagToList bag_of_errors
      sorted_errs = sortLt occ'ed_before bag_ls

      occ'ed_before (ErrMsg l1 _) (ErrMsg l2 _) = LT == compare l1 l2

pprBagOfWarnings :: Bag WarnMsg -> Pretty.Doc
pprBagOfWarnings bag_of_warns = pprBagOfErrors bag_of_warns
\end{code}

\begin{code}
ghcExit :: Int -> IO ()
ghcExit val
  | val == 0  = exitWith ExitSuccess
  | otherwise = do hPutStr stderr "\nCompilation had errors\n\n"
	           exitWith (ExitFailure val)
\end{code}

\begin{code}
doIfSet :: Bool -> IO () -> IO ()
doIfSet flag action | flag      = action
		    | otherwise = return ()

doIfSet_dyn :: DynFlags -> DynFlag -> IO () -> IO()
doIfSet_dyn dflags flag action | dopt flag dflags = action
		               | otherwise        = return ()
\end{code}

\begin{code}
showPass :: DynFlags -> String -> IO ()
showPass dflags what
  | verbosity dflags >= 2 = hPutStr stderr ("*** "++what++":\n")
  | otherwise		  = return ()

dumpIfSet :: Bool -> String -> SDoc -> IO ()
dumpIfSet flag hdr doc
  | not flag   = return ()
  | otherwise  = printDump (mkDumpDoc hdr doc)

dumpIfSet_core :: DynFlags -> DynFlag -> String -> SDoc -> IO ()
dumpIfSet_core dflags flag hdr doc
  | dopt flag dflags
	|| verbosity dflags >= 4
	|| dopt Opt_D_verbose_core2core dflags 	= printDump (mkDumpDoc hdr doc)
  | otherwise                                   = return ()

dumpIfSet_dyn :: DynFlags -> DynFlag -> String -> SDoc -> IO ()
dumpIfSet_dyn dflags flag hdr doc
  | dopt flag dflags || verbosity dflags >= 4 
  = if   flag `elem` [Opt_D_dump_stix, Opt_D_dump_asm]
    then printForC stdout (mkDumpDoc hdr doc)
    else printDump (mkDumpDoc hdr doc)
  | otherwise
  = return ()

dumpIfSet_dyn_or :: DynFlags -> [DynFlag] -> String -> SDoc -> IO ()
dumpIfSet_dyn_or dflags flags hdr doc
  | or [dopt flag dflags | flag <- flags]
  || verbosity dflags >= 4 
  = printDump (mkDumpDoc hdr doc)
  | otherwise = return ()

mkDumpDoc hdr doc 
   = vcat [text "", 
	   line <+> text hdr <+> line,
	   doc,
	   text ""]
     where 
        line = text (replicate 20 '=')
\end{code}
