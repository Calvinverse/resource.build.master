import jenkins.model.*;

// Start in locked down state so it doesn't start building straight away
println "Don't start building straight away."
Jenkins.instance.doQuietDown();
