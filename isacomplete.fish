# the Isabelle command to complete (defaults to just "isabelle")
# useful if you regularly use several Isabelle installations and e.g.
# have an alias like "isabelle-dev"
if [ -n $ISABELLE_CMD ]
  set -gx ISABELLE_CMD isabelle
end

# additional directories to manually scrape for ROOT/ROOTS files
#set -gx ISABELLE_SCRAPEDIRS $ISABELLE_HOME $HOME/afp/release

# auxiliary variables
set -gx ISABELLE_BIN (which $ISABELLE_CMD)
set -gx ISABELLE_HOME ($ISABELLE_BIN getenv -b ISABELLE_HOME)

# caching flags
set -gx ISABELLE_COMPLETE_USE_SESSION_CACHE false
set -gx ISABELLE_COMPLETE_USE_TOOL_CACHE false

# internal paths
set -gx CACHE_PATH $HOME/.cache/fish/isabelle_completion
set -gx SESSION_CACHE $CACHE_PATH/sessions
set -gx TOOL_CACHE $CACHE_PATH/tools



# create directory for caches if necessary
if $ISABELLE_COMPLETE_USE_SESSION_CACHE
  or $ISABELLE_COMPLETE_USE_TOOL_CACHE
  mkdir -p $HOME/.cache/fish/isabelle_completion
end


# scrape the output of "isabelle -?" to query all available Isabelle tools (i.e. "subcommands")
# this is mostly static information and can be cached, but it can change when e.g. a component like AFP is added
function __fish_complete_isabelle_scrapetools
  $ISABELLE_BIN -\? \
    | sed -ne '/^\s*Available tools:\s*$/{:a' -e 'n;p;ba' -e '}' \
    | sed -En 's/\s*(\S+) - (.*)$/\1\t\2/p'
end


# scrape the output of "isabelle $tool -?" to query all available options for $tool
function __fish_complete_isabelle_scrape_options
  set -f opts ($ISABELLE_BIN $argv[1] -\? 2> /dev/null \
    | sed -ne '/^\s*Options are:\s*$/{:a' -e 'n;p;ba' -e '}' \
    | sed -En 's/\s*-([A-Za-z])( ([A-Z]+))?.*  (.*)$/\1\t\3\t\4/p' \
    | string split -n '\n')
  for opt in $opts
    set -f opt (echo "$opt" | tr '\t' '\0' | string split0)
    printf '-%s\t%s\n' "$opt[1]" "$opt[3]"
  end
end

function __fish_complete_isabelle_fallback
  set -l COMP_WORDS (commandline -opc)
  set -l n (count $COMP_WORDS)
  if [ $n -lt 2 ]
    return
  end
  
  __fish_complete_isabelle_scrape_options $COMP_WORDS[2]
    or __fish_complete_path
end



# quick-and-dirty scraping of a ROOT file for session groups
function __fish_complete_isabelle_scrapegroups
  for i in $argv
    sed -En 's/^\s*session\s+(([A-Za-z0-9_]*)|"([A-Za-z0-9_+-]*)")\s*\((([A-Za-z0-9_-]|\s)+)\).*$/\4/p' $i \
      | tr '[:blank:]' '\n' | string split -n '\n' | sort | uniq
  end
end

function __fish_complete_isabelle_scrapegroup_dirs_aux
  if [ -f "$argv[1]/ROOT" ]
    __fish_complete_isabelle_scrapegroups "$argv[1]/ROOT";
  end
  if [ -f "$argv[1]/ROOTS" ]
    for r in (cat -- "$argv[1]/ROOTS")
      set r (string trim -- "$r")
      if [ $r != "" ]
        __fish_complete_isabelle_scrapegroup_dirs "$argv[1]/$r"
      end
    end
  end
end

function __fish_complete_isabelle_scrapegroup_dirs
  for d in $argv
    __fish_complete_isabelle_scrapegroup_dirs_aux "$d";
    __fish_complete_isabelle_scrapegroup_dirs_aux "$d/thys"
  end
end

function __fish_complete_isabelle_scrape_session_groups
  __fish_complete_isabelle_scrapegroup_dirs $argv | sort | uniq
end




# quick-and-dirty scraping of a ROOT file for sessions
function __fish_complete_isabelle_scraperoot
  for i in $argv
    sed -En 's/^\s*session\s+(([A-Za-z0-9_]*)|"([A-Za-z0-9_+-]*)")(\s|=).*$/\2\3/p' $i
  end
end

# Scrape the ROOT file in a directory (if present). If a ROOTS file is present,
# recursively scrape all the subdirectories "d" listed therein (and also "d/thys")
function __fish_complete_isabelle_procdiraux
  if [ -f "$argv[1]/ROOT" ]
    __fish_complete_isabelle_scraperoot "$argv[1]/ROOT";
  end
  if [ -f "$argv[1]/ROOTS" ]
    for r in (cat -- "$argv[1]/ROOTS")
      set r (string trim -- "$r")
      if [ $r != "" ]
        __fish_complete_isabelle_procdirs "$argv[1]/$r"
      end
    end
  end
end

# Scrape each given directory "d" and "d/thys" for ROOT/ROOTS files
function __fish_complete_isabelle_procdirs
  for d in $argv
    __fish_complete_isabelle_procdiraux "$d";
    __fish_complete_isabelle_procdiraux "$d/thys"
  end
end

function __fish_complete_isabelle_scrapesessions
  __fish_complete_isabelle_procdirs $argv | sort | uniq
end

# Scrape the output of "isabelle components" for all available and missing components
function __fish_complete_isabelle_components
  set -l comps ($ISABELLE_BIN components -l | sed -En 's/^\s+(\/.*)$/\1/p')
  for i in $comps
      echo -- (basename "$i")
  end
end

# print (possibly cached) suggestion for tools
function __fish_complete_isabelle_tools
  if $ISABELLE_COMPLETE_USE_TOOL_CACHE
    and [ -f "$TOOL_CACHE" ]
    cat -- "$TOOL_CACHE"
  else
    set -f tools (__fish_complete_isabelle_scrapetools)
    printf "%s\n" $tools
    if $ISABELLE_COMPLETE_USE_TOOL_CACHE
      and [ "$TOOL_CACHE" != "" ]
      printf "%s\n" $tools > $TOOL_CACHE
    end
  end
end

# determine if the current command line is of the form "isabelle foo ..." for some
# foo in the argument list
function __fish_isabelle_using_command
  set -l COMP_WORDS (commandline -opc)
  set -l n (count $COMP_WORDS)
  if [ $n -lt 2 ]
    return 1
  end
  if contains -- $COMP_WORDS[2] $argv
    return 0
  end
  return 1
end

# determine if the current command line is of the form "isabelle "
# (i.e. no command specified yet)
function __fish_isabelle_no_command
  set -l COMP_WORDS (commandline -opc)
  set -l n (count $COMP_WORDS)
  [ $n = 1 ]
end

# print completion suggestions for Isabelle session groups
function __fish_complete_isabelle_session_group
  set -l COMP_WORDS (commandline -opc)
  set -l n (count $COMP_WORDS)
  
  # Search the command line for manually included directories (via "-d" or "-D").
  # Scrape the ROOT files in these directories manually and give the sessions found
  # "included session" as a description and list them first in the completion, before
  # the global ones
  for i in (seq $n)[2..-2]
    set -l j (math $i + 1)
		if contains -- $COMP_WORDS[$i] $argv
		  and [ -n $COMP_WORDS[$j] ]
      for s in (__fish_complete_isabelle_scrape_session_groups $COMP_WORDS[$j])
        echo -e -- "$s\tsession group"
      end
    end
  end

  set -f components ($ISABELLE_BIN getenv -b ISABELLE_COMPONENTS | string split ':')
  for s in (__fish_complete_isabelle_scrape_session_groups $components)
    echo -e -- "$s\tsession group"
  end
end

# print completion suggestions for Isabelle sessions
function __fish_complete_isabelle_session
  set -l COMP_WORDS (commandline -opc)
  set -l n (count $COMP_WORDS)
  
  # Search the command line for manually included directories (via "-d" or "-D").
  # Scrape the ROOT files in these directories manually and give the sessions found
  # "included session" as a description and list them first in the completion, before
  # the global ones
  for i in (seq $n)[2..-2]
    set -l j (math $i + 1)
		if contains -- $COMP_WORDS[$i] $argv
		  and [ -n $COMP_WORDS[$j] ]
      for s in (__fish_complete_isabelle_scrapesessions $COMP_WORDS[$j])
        echo -e -- "$s\tincluded session"
      end
    end
  end

  if $ISABELLE_COMPLETE_USE_SESSION_CACHE
    and [ -f "$SESSION_CACHE" ]
    set -f sessions (cat -- "$SESSION_CACHE")
  else
    # use the "isabelle sessions" command to list all sessions known to Isabelle
    set -f sessions (__fish_complete_isabelle_scrapesessions $ISABELLE_SCRAPEDIRS) ($ISABELLE_BIN sessions -a)
    if $ISABELLE_COMPLETE_USE_SESSION_CACHE
      and [ "$SESSION_CACHE" != "" ]
      printf "%s\n" $sessions > $SESSION_CACHE
    end
  end
  for s in $sessions
    echo -e -- "$s\tglobal session" 
  end
end

# print completion suggestions for the AFP directory (i.e. directories
# plus ":" for the default)
function __fish_complete_afp_dir
  echo -e -- ':\tdefault: $AFP_BASE'
  __fish_complete_directories
end

# print completion suggestions for the presentation directory (i.e. directories
# plus ":" for the default)
function __fish_complete_pres_dir
  echo -e -- ':\tdefault'
  __fish_complete_directories
end




# Registering the completions

complete -c $ISABELLE_CMD -e # erase previous completions

# completion for "isabelle" (without a subcommand selected)
complete -c $ISABELLE_CMD -n '__fish_isabelle_no_command' --no-files -ra '(__fish_complete_isabelle_tools)'


# Completions for "jedit" subcommand
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command jedit'

## session name completions
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command jedit' -s l --no-files -rka '(__fish_complete_isabelle_session "-d")' -d 'logic session name'
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command jedit' -s A --no-files -ka '(__fish_complete_isabelle_session "-d")' -d 'ancestor session for option -R (default: parent)'
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command jedit' -s R --no-files -rka '(__fish_complete_isabelle_session "-d")' -d 'build image with requirements from other sessions'
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command jedit' -s i --no-files -rka '(__fish_complete_isabelle_session "-d")' -d 'include session in name-space of theories'

## directory completions
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command jedit' -s d --no-files -ra '(__fish_complete_directories)' -d 'include session directory'

## options
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command jedit' -s D -r -d 'set JVM system property'
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command jedit' -s J -r -d 'add JVM runtime option'
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command jedit' -s j -r -d 'add jEdit runtime option'
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command jedit' -s m -r -d 'add print mode for output'
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command jedit' -s p -r -d 'command prefix for ML process'

## boolean flags
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command jedit' -s b -d 'build only'
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command jedit' -s f -d 'fresh build'
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command jedit' -s n -d 'no build of session image on startup'
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command jedit' -s s -d 'system build mode'
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command jedit' -s u -d 'user build mode'




# Completions for "build" subcommand
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command build' --no-files -ka '(__fish_complete_isabelle_session "-d" "-D")' -d session

## session name completions
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command build' -s B --no-files -rka '(__fish_complete_isabelle_session "-d" "-D")' -d 'include session and descendants'
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command build' -s x --no-files -rka '(__fish_complete_isabelle_session "-d" "-D")' -d 'exclude session and descendants'

## session group completions
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command build' -s X --no-files -ra '(__fish_complete_isabelle_session_group "-d" "-D")' -d 'exclude session group and descendants'
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command build' -s g --no-files -ra '(__fish_complete_isabelle_session_group "-d" "-D")' -d 'select session group'

## directory completions
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command build' -s A --no-files -rka '(__fish_complete_afp_dir)' -d 'include AFP with given root directory'
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command build' -s P --no-files -ra '(__fish_complete_pres_dir)' -d 'enable HTML/PDF presentation in directory'
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command build' -s d --no-files -ra '(__fish_complete_directories)' -d 'include session directory'
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command build' -s D --no-files -ra '(__fish_complete_directories)' -d 'include session directory and select its sessions'

## boolean flags
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command build' -s c --no-files -d 'clean build'
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command build' -s b --no-files -d 'build heap images'
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command build' -s a --no-files -d 'select all sessions'
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command build' -s S --no-files -d 'soft build'
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command build' -s e --no-files -d 'export files from session specification'
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command build' -s f --no-files -d 'fresh build'
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command build' -s l --no-files -d 'list session source files'
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command build' -s n --no-files -d 'no build'
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command build' -s v --no-files -d 'verbose'

## other
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command build' -s j --no-files -ra '0\tunlimited 1\t 2\t 4\t 8\t 16\t 32\t 64\t 128\t 256\t ' -d 'max. number of parallel jobs'



# Completions for "components" subcommand

complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command components' --no-files -ka '(__fish_complete_isabelle_components)'

complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command components' -s I --no-files -d 'init user settings'
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command components' -s a --no-files -d 'resolve all missing components'
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command components' -s l --no-files -d 'list status'

complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command components' -s R -r --no-files -d 'component repository'
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command components' -s u -ra '(__fish_complete_directories)' --no-files -d 'add component directory'
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command components' -s x -ra '(__fish_complete_directories)' --no-files -d 'remove component directory'


# Completions for "sessions" subcommand

complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command sessions' --no-files -ka '(__fish_complete_isabelle_session "-d" "-D")' -d session

## session name completions
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command sessions' -s B --no-files -rka '(__fish_complete_isabelle_session "-d" "-D")' -d 'include session and descendants'
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command sessions' -s x --no-files -rka '(__fish_complete_isabelle_session "-d" "-D")' -d 'exclude session and descendents'

## session group completions
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command sessions' -s X --no-files -ra '(__fish_complete_isabelle_session_group "-d" "-D")' -d 'exclude session group and descendants'
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command sessions' -s g --no-files -ra '(__fish_complete_isabelle_session_group "-d" "-D")' -d 'select session group'

## boolean flags
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command sessions' -s R --no-files -d 'refer to requirements of selected sessions'
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command sessions' -s a --no-files -d 'select all sessions'
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command sessions' -s b --no-files -d 'follow session build dependencies'

## directory completions
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command sessions' -s D --no-files -ra '(__fish_complete_directories)' -d 'include session directory and select its sessions'
complete -c $ISABELLE_CMD -n '__fish_isabelle_using_command sessions' -s d --no-files -ra '(__fish_complete_directories)' -d 'include session directory'


# Fallback for unsupported subcommand

# TODO: more robust handling of options
#complete -c $ISABELLE_CMD --no-files -ra '(__fish_complete_isabelle_fallback)'

