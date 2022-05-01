#!/bin/sh
# Copyright 2000-2021 JetBrains s.r.o. and contributors. Use of this source code is governed by the Apache 2.0 license that can be found in the LICENSE file.

# ---------------------------------------------------------------------
# IntelliJ IDEA startup script.
# ---------------------------------------------------------------------

JDK_VERSION=11 # change this to point to different JDKs on your machine, will look in /usr/lib64/openjdk-#

message()
{
  TITLE="Cannot start IntelliJ IDEA"
  if [ -n "$(command -v zenity)" ]; then
    zenity --error --title="$TITLE" --text="$1" --no-wrap
  elif [ -n "$(command -v kdialog)" ]; then
    kdialog --error "$1" --title "$TITLE"
  elif [ -n "$(command -v notify-send)" ]; then
    notify-send "ERROR: $TITLE" "$1"
  elif [ -n "$(command -v xmessage)" ]; then
    xmessage -center "ERROR: $TITLE: $1"
  else
    printf "ERROR: %s\n%s\n" "$TITLE" "$1"
  fi
}

if [ -z "$(command -v uname)" ] || [ -z "$(command -v realpath)" ] || [ -z "$(command -v dirname)" ] || [ -z "$(command -v cat)" ] || \
   [ -z "$(command -v egrep)" ]; then
  TOOLS_MSG="Required tools are missing:"
  for tool in uname realpath egrep dirname cat ; do
     test -z "$(command -v $tool)" && TOOLS_MSG="$TOOLS_MSG $tool"
  done
  message "$TOOLS_MSG (SHELL=$SHELL PATH=$PATH)"
  exit 1
fi

# shellcheck disable=SC2034
GREP_OPTIONS=''
OS_TYPE=$(uname -s)
OS_ARCH=$(uname -m)

# ---------------------------------------------------------------------
# Ensure $IDE_HOME points to the directory where the IDE is installed.
# ---------------------------------------------------------------------
IDE_BIN_HOME=$(dirname "$(realpath "$0")")
IDE_HOME=$(dirname "${IDE_BIN_HOME}")
CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"

# ---------------------------------------------------------------------
# Locate a JRE installation directory command -v will be used to run the IDE.
# Try (in order): $IDEA_JDK, .../idea.jdk, .../jbr, $JDK_HOME, $JAVA_HOME, "java" in $PATH.
# ---------------------------------------------------------------------
JRE=""

# shellcheck disable=SC2154
if [ -n "$IDEA_JDK" ] && [ -x "$IDEA_JDK/bin/java" ]; then
  JRE="$IDEA_JDK"
## You added this.  Because Gentoo's system vm is still java 8 and idea requires newer java ##
else
  [[ -d "/usr/lib64/openjdk-$JDK_VERSION" ]] && JDK="/usr/lib64/openjdk-$JDK_VERSION" && JRE=$JDK 
  echo "Using $JDK as JDK"
fi

if [ -z "$JRE" ] && [ -s "${CONFIG_HOME}/JetBrains/IdeaIC2022.1/idea.jdk" ]; then
  USER_JRE=$(cat "${CONFIG_HOME}/JetBrains/IdeaIC2022.1/idea.jdk")
  if [ -x "$USER_JRE/bin/java" ]; then
    JRE="$USER_JRE"
  fi
fi

if [ -z "$JRE" ] && [ "$OS_TYPE" = "Linux" ] && [ "$OS_ARCH" = "x86_64" ] && [ -d "$IDE_HOME/jbr" ]; then
  JRE="$IDE_HOME/jbr"
fi

# shellcheck disable=SC2153
if [ -z "$JRE" ]; then
  if [ -n "$JDK_HOME" ] && [ -x "$JDK_HOME/bin/java" ]; then
    JRE="$JDK_HOME"
  elif [ -n "$JAVA_HOME" ] && [ -x "$JAVA_HOME/bin/java" ]; then
    JRE="$JAVA_HOME"
  fi
fi

if [ -z "$JRE" ]; then
  JAVA_BIN=$(command -v java)
else
  JAVA_BIN="$JRE/bin/java"
fi

if [ -z "$JAVA_BIN" ] || [ ! -x "$JAVA_BIN" ]; then
  message "No JRE found. Please make sure \$IDEA_JDK, \$JDK_HOME, or \$JAVA_HOME point to valid JRE installation."
  exit 1
fi

# ---------------------------------------------------------------------
# Collect JVM options and IDE properties.
# ---------------------------------------------------------------------
IDE_PROPERTIES_PROPERTY=""
# shellcheck disable=SC2154
if [ -n "$IDEA_PROPERTIES" ]; then
  IDE_PROPERTIES_PROPERTY="-Didea.properties.file=$IDEA_PROPERTIES"
fi

VM_OPTIONS_FILE=""
USER_VM_OPTIONS_FILE=""
# shellcheck disable=SC2154
if [ -n "$IDEA_VM_OPTIONS" ] && [ -r "$IDEA_VM_OPTIONS" ]; then
  # 1. $<IDE_NAME>_VM_OPTIONS
  VM_OPTIONS_FILE="$IDEA_VM_OPTIONS"
else
  # 2. <IDE_HOME>/bin/[<os>/]<bin_name>.vmoptions ...
  if [ -r "${IDE_BIN_HOME}/idea64.vmoptions" ]; then
    VM_OPTIONS_FILE="${IDE_BIN_HOME}/idea64.vmoptions"
  else
    test "${OS_TYPE}" = "Darwin" && OS_SPECIFIC="mac" || OS_SPECIFIC="linux"
    if [ -r "${IDE_BIN_HOME}/${OS_SPECIFIC}/idea64.vmoptions" ]; then
      VM_OPTIONS_FILE="${IDE_BIN_HOME}/${OS_SPECIFIC}/idea64.vmoptions"
    fi
  fi
  # ... [+ <IDE_HOME>.vmoptions (Toolbox) || <config_directory>/<bin_name>.vmoptions]
  if [ -r "${IDE_HOME}.vmoptions" ]; then
    USER_VM_OPTIONS_FILE="${IDE_HOME}.vmoptions"
  elif [ -r "${CONFIG_HOME}/JetBrains/IdeaIC2022.1/idea64.vmoptions" ]; then
    USER_VM_OPTIONS_FILE="${CONFIG_HOME}/JetBrains/IdeaIC2022.1/idea64.vmoptions"
  fi
fi

VM_OPTIONS=""
USER_GC=""
if [ -n "$USER_VM_OPTIONS_FILE" ]; then
  grep -E -q -e "-XX:\+.*GC" "$USER_VM_OPTIONS_FILE" && USER_GC="yes"
fi
if [ -n "$VM_OPTIONS_FILE" ] || [ -n "$USER_VM_OPTIONS_FILE" ]; then
  if [ -z "$USER_GC" ] || [ -z "$VM_OPTIONS_FILE" ]; then
    VM_OPTIONS=$(cat "$VM_OPTIONS_FILE" "$USER_VM_OPTIONS_FILE" 2> /dev/null | grep -E -v -e "^#.*")
  else
    VM_OPTIONS=$({ grep -E -v -e "-XX:\+Use.*GC" "$VM_OPTIONS_FILE"; cat "$USER_VM_OPTIONS_FILE"; } 2> /dev/null | grep -E -v -e "^#.*")
  fi
else
  message "Cannot find a VM options file"
fi

CLASS_PATH="$IDE_HOME/lib/util.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/app.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/3rd-party-rt.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/jna.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/platform-statistics-devkit.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/jps-model.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/rd-core.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/rd-framework.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/stats.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/protobuf.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/external-system-rt.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/jsp-base-openapi.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/forms_rt.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/intellij-test-discovery.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/rd-swing.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/annotations.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/groovy.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/annotations-java5.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/byte-buddy-agent.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/dom-impl.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/dom-openapi.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/duplicates-analysis.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/error-prone-annotations.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/externalProcess-rt.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/grpc-netty-shaded.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/idea_rt.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/intellij-coverage-agent-1.0.656.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/jsch-agent.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/junit.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/junit4.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/junixsocket-core.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/lz4-java.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/platform-objectSerializer-annotations.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/pty4j.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/rd-text.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/structuralsearch.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/tests_bootstrap.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/uast-tests.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/util_rt.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/winp.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/ant/lib/ant.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/dbus-java-3.2.1.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/java-utils-1.0.6.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/jnr-unixsocket-0.23.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/jnr-ffi-2.1.10.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/jffi-1.2.19.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/jffi-1.2.19-native.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/asm-7.1.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/asm-commons-7.1.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/asm-analysis-7.1.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/asm-tree-7.1.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/asm-util-7.1.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/jnr-a64asm-1.0.0.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/jnr-x86asm-1.0.2.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/jnr-constants-0.9.12.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/jnr-enxio-0.21.jar"
CLASS_PATH="$CLASS_PATH:$IDE_HOME/lib/jnr-posix-3.0.50.jar"

# ---------------------------------------------------------------------
# Run the IDE.
# ---------------------------------------------------------------------
IFS="$(printf '\n\t')"
# shellcheck disable=SC2086
"$JAVA_BIN" \
  -classpath "$CLASS_PATH" \
  ${VM_OPTIONS} \
  "-XX:ErrorFile=$HOME/java_error_in_idea_%p.log" \
  "-XX:HeapDumpPath=$HOME/java_error_in_idea_.hprof" \
  "-Djb.vmOptionsFile=${USER_VM_OPTIONS_FILE:-${VM_OPTIONS_FILE}}" \
  ${IDE_PROPERTIES_PROPERTY} \
  -Djava.system.class.loader=com.intellij.util.lang.PathClassLoader -Didea.strict.classpath=true -Didea.vendor.name=JetBrains -Didea.paths.selector=IdeaIC2022.1 -Didea.platform.prefix=Idea -Didea.jre.check=true -Dsplash=true \
  com.intellij.idea.Main \
  "$@"
