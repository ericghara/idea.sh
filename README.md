# idea.sh
Modified IntelliJ Idea start script that uses non-system JVM

## Info
The Gentoo Linux IntelliJ Idea package does not include JetBeans' own JDK and the current Gentoo system VM is Java 8, which is too old to run Idea.  Upgrading the Gentoo system-vm is not an option as it breaks Gentoo.  This modification to the idea.sh script changes the default behavior of Idea to use openjdk-11 instead of the system VM when JetBeans's own VM is unavailable.  I'm archiving this here as no doubt the next IntellJ update will overwrite this script.
