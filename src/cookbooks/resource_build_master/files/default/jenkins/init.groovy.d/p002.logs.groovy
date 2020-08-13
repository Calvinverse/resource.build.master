import java.util.logging.ConsoleHandler
import java.util.logging.FileHandler
import java.util.logging.Level
import java.util.logging.Logger
import java.util.logging.LogManager
import java.util.logging.SimpleFormatter
import jenkins.model.Jenkins

// Because Jenkins is dumb we have to play games to get all the logs
// See: https://wiki.jenkins.io/display/JENKINS/Logging#Logging-MakinglogsavailableoutsideofthewebUI

def handler = new ConsoleHandler(level: Level.ALL)

def webAppMainLogger = LogManager.getLogManager().getLogger('hudson.WebAppMain')
webAppMainLogger?.setLevel(Level.ALL)
webAppMainLogger?.addHandler(handler)

def runLogger = LogManager.getLogManager().getLogger('hudson.model.Run')
runLogger?.setLevel(Level.ALL)
runLogger?.addHandler(handler)

def jobDslLogger = LogManager.getLogManager().getLogger('javaposse.jobdsl')
jobDslLogger?.setLevel(Level.ALL)
jobDslLogger?.addHandler(handler)
