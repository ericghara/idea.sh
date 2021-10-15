# idea.sh
Modified IntelliJ Idea startscript which uses non-system JVM

## Info
The Gentoo linux system vm is JDK 8, IntelliJ requieres a more recent VM.  Additionally, the Gentoo IntelliJ Idea package does not include JetBeans's proprietary JDK.  This simple modification to the idea.sh script points IntelliJ to openjdk-11.  I'm archiving this here as no doubt the next IntellJ update will overwrite this script.
