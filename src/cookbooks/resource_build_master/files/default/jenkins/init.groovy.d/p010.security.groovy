#!groovy
import jenkins.model.*
import hudson.security.*
import java.util.*
import com.michelin.cio.hudson.plugins.rolestrategy.*
import java.lang.reflect.*

def findRoleEntry(grantedRoles, roleName)
{
  for (def entry : grantedRoles)
  {
    Role role = entry.getKey()

    if (role.getName().equals(roleName))
    {
      return entry
    }
  }

  return null
}

def instance = Jenkins.getInstance()

// Create the users:
def hudsonRealm = new HudsonPrivateSecurityRealm(false)

def adminUser = "admin"
hudsonRealm.createAccount(adminUser,'admin')

def nodeUser = "user.node"
hudsonRealm.createAccount(nodeUser,'user.node')

instance.setSecurityRealm(hudsonRealm)

// Add the users to the different roles
def authStrategy = instance.getAuthorizationStrategy()
if (authStrategy instanceof RoleBasedAuthorizationStrategy)
{
    RoleBasedAuthorizationStrategy roleAuthStrategy = (RoleBasedAuthorizationStrategy) authStrategy

    // Make constructors available
    Constructor[] constrs = Role.class.getConstructors();
    for (Constructor<?> c : constrs)
    {
        c.setAccessible(true);
    }
    // Make the method assignRole accessible
    Method assignRoleMethod =  RoleBasedAuthorizationStrategy.class.getDeclaredMethod("assignRole", String.class, Role.class, String.class);
    assignRoleMethod.setAccessible(true);

    // Grant the authenticated global role
    println "Searching for global roles ..."
    def grantedGlobalRoles = authStrategy.getGrantedRoles(RoleBasedAuthorizationStrategy.GLOBAL);
    if (grantedGlobalRoles != null)
    {
        def roleName = "global.authenticated"
        println "Searchin for role name: " + roleName + " ..."
        def roleEntry = findRoleEntry(grantedGlobalRoles, roleName);
        if (roleEntry != null)
        {
            def sidList = roleEntry.getValue()
            if (!sidList.contains(nodeUser))
            {
                println "Adding: " + nodeUser + " to role: " + roleName + " ..."
                roleAuthStrategy.assignRole(RoleBasedAuthorizationStrategy.GLOBAL, roleEntry.getKey(), nodeUser);
            }
        }
        else
        {
            println "Role name: " + roleName + " not found"
        }
    }
    else
    {
        println "No global roles found!"
    }

    // Grant the agent.connect slave role
    println "Searching for agent roles ..."
    def grantedSlaveRoles = authStrategy.getGrantedRoles(RoleBasedAuthorizationStrategy.SLAVE);
    if (grantedSlaveRoles != null)
    {
        def roleName = "agent.connect"
        println "Searchin for role name: " + roleName + " ..."
        def roleEntry = findRoleEntry(grantedSlaveRoles, roleName);
        if (roleEntry != null)
        {
            def sidList = roleEntry.getValue()
            if (!sidList.contains(nodeUser))
            {
                println "Adding: " + nodeUser + " to role: " + roleName + " ..."
                roleAuthStrategy.assignRole(RoleBasedAuthorizationStrategy.GLOBAL, roleEntry.getKey(), nodeUser);
            }
        }
        else
        {
            println "Role name: " + roleName + " not found"
        }
    }
    else
    {
        println "No agent roles found!"
    }

    instance.save()
}
else
{
    println "Role Strategy Plugin not found!"
}
