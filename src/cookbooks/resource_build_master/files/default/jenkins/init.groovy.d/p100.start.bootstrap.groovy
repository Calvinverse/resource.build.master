#!groovy

import hudson.model.*;

def bootstrapJob = Hudson.instance.getItemByFullName('meta/bootstrap');

println "Scheduling build for meta/bootstrap ..."
bootstrapJob.scheduleBuild();
