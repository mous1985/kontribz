package kontribz

import (
	"std"
	"strconv"
	"strings"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/mux"
	"gno.land/p/moul/md"
	"gno.land/p/moul/txlink"
	"gno.land/r/demo/profile"
)

var (
	router        = mux.NewRouter()
	realmPath     = "/r/kontribz"
	organizations avl.Tree // orgID -> *Organization
	tasks         avl.Tree // taskID -> *Task
	applications  avl.Tree // appID -> *Application
	orgCounter    int      // organization counter
	taskCounter   int      // task counter
	appCounter    int      // application counter
)

type Organization struct {
	ID        int
	Name      string
	Avatar    string
	Domain    string
	Bio       string
	Website   string
	Admin     std.Address
	Tasks     []int // task IDs
	CreatedAt int64
}

type Task struct {
	ID             int
	OrganizationID int
	Title          string
	Description    string
	Reward         string
	Status         TaskStatus
	Assignee       std.Address
	Applications   []int // application IDs
	CreatedAt      int64
	KanbanStatus   KanbanStatus // for kanban tracking
}

type Application struct {
	ID        int
	TaskID    int
	Applicant std.Address
	Message   string
	Status    ApplicationStatus
	AppliedAt int64
}

type TaskStatus int

const (
	TaskOpen TaskStatus = iota
	TaskAssigned
	TaskCompleted
)

type ApplicationStatus int

const (
	AppPending ApplicationStatus = iota
	AppAccepted
	AppRejected
)

type KanbanStatus int

const (
	KanbanTodo KanbanStatus = iota
	KanbanInProgress
	KanbanReview
	KanbanDone
)

func init() {
	router.HandleFunc("", homeHandler)
	router.HandleFunc("profile/create", profileCreateHandler)
	router.HandleFunc("organization/create", organizationCreateHandler)
	router.HandleFunc("organization/{id}", organizationHandler)
	router.HandleFunc("organization/{id}/kanban", organizationKanbanHandler)
	router.HandleFunc("organizations", organizationsHandler)
	router.HandleFunc("task/create", taskCreateHandler)
	router.HandleFunc("task/{id}", taskHandler)
	router.HandleFunc("tasks", tasksHandler)
	router.HandleFunc("users", usersHandler)
	router.HandleFunc("user/{addr}", userHandler)
	router.HandleFunc("user/{addr}/kanban", userKanbanHandler)
}

func Render(path string) string {
	return router.Render(path)
}

func homeHandler(res *mux.ResponseWriter, req *mux.Request) {
	var out string
	out += md.H1("🎯 Kontribz - Bounty Manager") + "\n\n"

	out += md.H2("📊 Platform Statistics") + "\n\n"
	orgCount := organizations.Size()
	taskCount := tasks.Size()
	appCount := applications.Size()
	out += md.BulletList([]string{
		md.Bold("Organizations:") + " " + strconv.Itoa(orgCount),
		md.Bold("Tasks:") + " " + strconv.Itoa(taskCount),
		md.Bold("Applications:") + " " + strconv.Itoa(appCount),
	}) + "\n\n"

	out += md.H2("🚀 Quick Actions") + "\n\n"
	out += md.BulletList([]string{
		md.Link("Create Your Profile", realmPath+":profile/create") + " - Start by creating your user profile",
		md.Link("Create Organization", realmPath+":organization/create") + " - Create your organization",
		md.Link("Browse Organizations", realmPath+":organizations") + " - View all organizations",
		md.Link("Browse Tasks", realmPath+":tasks") + " - View all tasks",
		md.Link("Browse Users", realmPath+":users") + " - View all users",
	}) + "\n\n"

	res.Write(out)
}

func profileCreateHandler(res *mux.ResponseWriter, req *mux.Request) {
	var out string
	out += md.H1("👤 Create Profile") + "\n\n"
	out += "Click the link below to connect and set up your profile:\n\n"

	connectionLink := txlink.Realm("gno.land/r/demo/profile").Call("SetStringField", "DisplayName", "New User")
	out += "🔗 " + md.Bold(md.Link(("Connetion"), connectionLink)) + "\n\n"

	out += md.Italic("This will create a basic profile with the display name 'New User'.") + "\n\n"

	res.Write(out)
}

func organizationCreateHandler(res *mux.ResponseWriter, req *mux.Request) {
	var out string

	out += md.H1("🏢 Create Organization") + "\n\n"
	out += md.Link("← Back to Home", realmPath) + "\n\n"

	out += "Create your organization to manage bounties and tasks.\n\n"

	out += md.H2("Organization Form") + "\n\n"
	out += "To create your organization, you can call the `CreateOrganization` function or use these quick templates:\n\n"

	out += md.H3("🚀 Quick Templates") + "\n\n"

	createOrgLink := txlink.Call("CreateOrganization", "name", "", "domain", "", "bio", "", "website", "", "avatar", "")
	out += md.Bold("Create your organizations:") + " " + md.Link("Create", createOrgLink) + "\n\n"

	out += md.Bold("Parameters:") + "\n"
	out += md.BulletList([]string{
		md.Bold("Name") + " (required): Organization name",
		md.Bold("Domain") + " (required): Unique domain/handle",
		md.Bold("Bio") + " (optional): Organization description",
		md.Bold("Website") + " (optional): Organization website",
		md.Bold("Avatar") + " (optional): Organization avatar URL",
	}) + "\n\n"

	res.Write(out)
}

func taskCreateHandler(res *mux.ResponseWriter, req *mux.Request) {
	var out string

	out += md.H1("📝 Create Task") + "\n\n"
	out += md.Link("← Back to Home", realmPath) + "\n\n"

	caller := std.OriginCaller()

	// Get user's organizations
	userOrgs := getUserOrganizations(caller)

	if len(userOrgs) == 0 {
		out += md.H2("❌ No Organizations Found") + "\n\n"
		out += "You need to be an admin of at least one organization to create tasks.\n\n"
		out += md.Link("Create Organization", realmPath+":organization/create") + "\n\n"
		res.Write(out)
		return
	}

	out += "Create a new task/bounty for one of your organizations.\n\n"

	out += md.H2("Your Organizations") + "\n\n"
	for _, org := range userOrgs {
		out += md.H3(org.Name+" (ID: "+strconv.Itoa(org.ID)+")") + "\n\n"

		createTaskLink := txlink.Call("CreateTask",
			strconv.Itoa(org.ID), // orgID
			"",                   // title
			"",                   // description
			"")                   // reward

		out += md.Bold("Create task for this organization:") + " " + md.Link("Create Task", createTaskLink) + "\n\n"
	}

	out += md.H2("Task Parameters") + "\n\n"
	out += "When creating a task, you need to provide:\n"
	out += md.BulletList([]string{
		md.Bold("Organization ID") + " (required): ID of your organization",
		md.Bold("Title") + " (required): Task title",
		md.Bold("Description") + " (required): Task description",
		md.Bold("Reward") + " (optional): Reward for completing the task",
	}) + "\n\n"

	res.Write(out)
}

func tasksHandler(res *mux.ResponseWriter, req *mux.Request) {
	var out string

	out += md.H1("📋 All Tasks") + "\n\n"
	out += md.Link("← Back to Home", realmPath) + "\n\n"

	taskCount := tasks.Size()
	if taskCount == 0 {
		out += md.Bold("No tasks yet.") + "\n\n"
		out += "Organizations can create tasks for their bounties.\n\n"
		out += md.Link("Create First Task", realmPath+":task/create") + "\n\n"
		res.Write(out)
		return
	}

	out += md.Bold("Total Tasks:") + " " + strconv.Itoa(taskCount) + "\n\n"

	// Collect tasks by status
	openTasks := []*Task{}
	assignedTasks := []*Task{}
	completedTasks := []*Task{}

	tasks.Iterate("", "", func(key string, value interface{}) bool {
		task := value.(*Task)
		switch task.Status {
		case TaskOpen:
			openTasks = append(openTasks, task)
		case TaskAssigned:
			assignedTasks = append(assignedTasks, task)
		case TaskCompleted:
			completedTasks = append(completedTasks, task)
		}
		return false
	})

	// Display open tasks
	out += md.H2("🟢 Open Tasks ("+strconv.Itoa(len(openTasks))+")") + "\n\n"
	if len(openTasks) == 0 {
		out += "No open tasks.\n\n"
	} else {
		for _, task := range openTasks {
			out += renderTaskSummary(task)
		}
	}

	// Display assigned tasks
	out += md.H2("🟡 Assigned Tasks ("+strconv.Itoa(len(assignedTasks))+")") + "\n\n"
	if len(assignedTasks) == 0 {
		out += "No assigned tasks.\n\n"
	} else {
		for _, task := range assignedTasks {
			out += renderTaskSummary(task)
		}
	}

	// Display completed tasks
	out += md.H2("✅ Completed Tasks ("+strconv.Itoa(len(completedTasks))+")") + "\n\n"
	if len(completedTasks) == 0 {
		out += "No completed tasks.\n\n"
	} else {
		for _, task := range completedTasks {
			out += renderTaskSummary(task)
		}
	}

	res.Write(out)
}

func taskHandler(res *mux.ResponseWriter, req *mux.Request) {
	var out string

	taskIDStr := req.GetVar("id")
	taskID, err := strconv.Atoi(taskIDStr)
	if err != nil {
		out += md.H1("❌ Error") + "\n\n"
		out += "Invalid task ID: " + taskIDStr + "\n"
		res.Write(out)
		return
	}

	task := getTask(taskID)
	if task == nil {
		out += md.H1("❌ Not Found") + "\n\n"
		out += "Task #" + taskIDStr + " not found.\n\n"
		out += md.Link("← Back to Tasks", realmPath+":tasks") + "\n"
		res.Write(out)
		return
	}

	org := getOrganization(task.OrganizationID)
	if org == nil {
		out += md.H1("❌ Error") + "\n\n"
		out += "Organization not found for this task.\n"
		res.Write(out)
		return
	}

	out += md.H1("📝 "+task.Title) + "\n\n"
	out += md.Link("← Back to Tasks", realmPath+":tasks") + " | "
	out += md.Link("View Organization", realmPath+":organization/"+strconv.Itoa(org.ID)) + "\n\n"

	// Task info
	taskInfoItems := []string{
		md.Bold("Organization:") + " " + md.Link(org.Name, realmPath+":organization/"+strconv.Itoa(org.ID)),
		md.Bold("Status:") + " " + getTaskStatusText(task.Status),
	}

	if task.Reward != "" {
		taskInfoItems = append(taskInfoItems, md.Bold("Reward:")+" "+task.Reward)
	}

	if task.Assignee != "" {
		assigneeName := profile.GetStringField(task.Assignee, "DisplayName", "Unknown")
		taskInfoItems = append(taskInfoItems, md.Bold("Assignee:")+" "+assigneeName+" (`"+task.Assignee.String()+"`)")
		taskInfoItems = append(taskInfoItems, md.Bold("Kanban Status:")+" "+getKanbanStatusText(task.KanbanStatus))
	}

	taskInfoItems = append(taskInfoItems, md.Bold("Created:")+" Block #"+strconv.FormatInt(task.CreatedAt, 10))

	out += md.BulletList(taskInfoItems) + "\n\n"

	out += md.H2("Description") + "\n\n"
	out += task.Description + "\n\n"

	// Applications section
	out += md.H2("📨 Applications ("+strconv.Itoa(len(task.Applications))+")") + "\n\n"

	caller := std.OriginCaller()

	// Show apply button if task is open and user hasn't applied
	if task.Status == TaskOpen {
		hasApplied := false
		for _, appID := range task.Applications {
			app := getApplication(appID)
			if app != nil && app.Applicant == caller {
				hasApplied = true
				break
			}
		}

		if !hasApplied {
			out += md.H3("🙋 Apply for this task") + "\n\n"

			applyLink := txlink.Call("ApplyToTask",
				strconv.Itoa(task.ID), // taskID
				"")                    // message

			out += md.Bold("Apply for this task:") + " " + md.Link("Apply", applyLink) + "\n\n"
			out += md.Italic("Note: You can provide a message explaining why you're the right person for this task.") + "\n\n"
		} else {
			out += md.Bold("✅ You have already applied for this task.") + "\n\n"
		}
	}

	// Show applications
	if len(task.Applications) == 0 {
		out += "No applications yet.\n\n"
	} else {
		for _, appID := range task.Applications {
			app := getApplication(appID)
			if app != nil {
				status := getApplicationStatusText(app.Status)
				applicantName := profile.GetStringField(app.Applicant, "DisplayName", "Unknown")

				out += md.HorizontalRule() + "\n\n"

				appInfoItems := []string{
					md.Bold("Applicant:") + " " + applicantName + " (`" + app.Applicant.String() + "`)",
					md.Bold("Status:") + " " + status,
					md.Bold("Applied:") + " Block #" + strconv.FormatInt(app.AppliedAt, 10),
				}

				if app.Message != "" {
					appInfoItems = append(appInfoItems, md.Bold("Message:")+" "+app.Message)
				}

				out += md.BulletList(appInfoItems) + "\n"

				// Admin actions for pending applications
				if caller == org.Admin && app.Status == AppPending {
					out += "\n" + md.Bold("Admin Actions:") + "\n"
					out += md.Italic("Go to your "+md.Link("organization page", realmPath+":organization/"+strconv.Itoa(org.ID))+" to accept or reject applications.") + "\n"
				}

				out += "\n"
			}
		}
	}

	// Admin actions
	if caller == org.Admin {
		out += md.H2("⚙️ Admin Actions") + "\n\n"
		adminActions := []string{}
		if task.Status == TaskOpen {
			adminActions = append(adminActions, "Review applications above to assign this task")
		} else if task.Status == TaskAssigned {
			adminActions = append(adminActions, "Task is currently assigned to "+profile.GetStringField(task.Assignee, "DisplayName", "Unknown"))
		}
		adminActions = append(adminActions, "Edit Task (coming soon)")
		adminActions = append(adminActions, "Delete Task (coming soon)")

		out += md.BulletList(adminActions) + "\n\n"
	}

	res.Write(out)
}

func usersHandler(res *mux.ResponseWriter, req *mux.Request) {
	var out string

	out += md.H1("👥 All Users") + "\n\n"
	out += md.Link("← Back to Home", realmPath) + "\n\n"

	// Collect all unique users from organizations, tasks, and applications
	userSet := make(map[string]bool)

	// Collect users from organizations (admins)
	organizations.Iterate("", "", func(key string, value interface{}) bool {
		org := value.(*Organization)
		userSet[org.Admin.String()] = true
		return false
	})

	// Collect users from tasks (assignees)
	tasks.Iterate("", "", func(key string, value interface{}) bool {
		task := value.(*Task)
		if task.Assignee != "" {
			userSet[task.Assignee.String()] = true
		}
		return false
	})

	// Collect users from applications (applicants)
	applications.Iterate("", "", func(key string, value interface{}) bool {
		app := value.(*Application)
		userSet[app.Applicant.String()] = true
		return false
	})

	if len(userSet) == 0 {
		out += md.Bold("No users found yet.") + "\n\n"
		out += "Users will appear here as they create organizations, apply to tasks, or get assigned to tasks.\n\n"
		res.Write(out)
		return
	}

	out += md.Bold("Total Users:") + " " + strconv.Itoa(len(userSet)) + "\n\n"

	// Display users
	for addrStr := range userSet {
		addr := std.Address(addrStr)
		name := profile.GetStringField(addr, "DisplayName", "Unknown")

		out += md.HorizontalRule() + "\n\n"
		out += md.H3(md.Link(name, realmPath+":user/"+addrStr)) + "\n\n"

		// Count user's organizations
		userOrgs := getUserOrganizations(addr)

		// Count user's applications
		userAppCount := 0
		applications.Iterate("", "", func(key string, value interface{}) bool {
			app := value.(*Application)
			if app.Applicant == addr {
				userAppCount++
			}
			return false
		})

		// Count assigned tasks
		assignedTaskCount := 0
		tasks.Iterate("", "", func(key string, value interface{}) bool {
			task := value.(*Task)
			if task.Assignee == addr {
				assignedTaskCount++
			}
			return false
		})

		userInfoItems := []string{
			md.Bold("Address:") + " `" + addrStr + "`",
			md.Bold("Organizations:") + " " + strconv.Itoa(len(userOrgs)),
			md.Bold("Applications:") + " " + strconv.Itoa(userAppCount),
			md.Bold("Assigned Tasks:") + " " + strconv.Itoa(assignedTaskCount),
		}

		out += md.BulletList(userInfoItems) + "\n\n"
	}

	res.Write(out)
}

func userHandler(res *mux.ResponseWriter, req *mux.Request) {
	var out string

	addrStr := req.GetVar("addr")
	addr := std.Address(addrStr)

	// Get profile info
	name := profile.GetStringField(addr, "DisplayName", "Unknown")

	out += md.H1("👤 "+name) + "\n\n"
	out += md.Link("← Back to Users", realmPath+":users") + "\n\n"

	// Profile info
	out += md.Bold("Address:") + " `" + addrStr + "`\n\n"

	// User's organizations
	userOrgs := getUserOrganizations(addr)
	if len(userOrgs) > 0 {
		out += md.H2("🏢 Organizations ("+strconv.Itoa(len(userOrgs))+")") + "\n\n"
		for _, org := range userOrgs {
			out += md.BulletItem(md.Link(org.Name, realmPath+":organization/"+strconv.Itoa(org.ID))+" - "+strconv.Itoa(len(org.Tasks))+" tasks") + "\n"
		}
		out += "\n"
	}

	// User's applications
	out += md.H2("📨 Applications") + "\n\n"

	pendingApps := []*Application{}
	acceptedApps := []*Application{}
	rejectedApps := []*Application{}

	applications.Iterate("", "", func(key string, value interface{}) bool {
		app := value.(*Application)
		if app.Applicant == addr {
			switch app.Status {
			case AppPending:
				pendingApps = append(pendingApps, app)
			case AppAccepted:
				acceptedApps = append(acceptedApps, app)
			case AppRejected:
				rejectedApps = append(rejectedApps, app)
			}
		}
		return false
	})

	// Pending applications
	out += md.H3("⏳ Pending ("+strconv.Itoa(len(pendingApps))+")") + "\n\n"
	if len(pendingApps) == 0 {
		out += "No pending applications.\n\n"
	} else {
		pendingItems := []string{}
		for _, app := range pendingApps {
			task := getTask(app.TaskID)
			if task != nil {
				org := getOrganization(task.OrganizationID)
				if org != nil {
					pendingItems = append(pendingItems, md.Link(task.Title, realmPath+":task/"+strconv.Itoa(task.ID))+" at "+md.Link(org.Name, realmPath+":organization/"+strconv.Itoa(org.ID)))
				}
			}
		}
		out += md.BulletList(pendingItems) + "\n\n"
	}

	// Accepted applications (assigned tasks)
	out += md.H3("✅ Accepted/Assigned ("+strconv.Itoa(len(acceptedApps))+")") + "\n\n"
	if len(acceptedApps) == 0 {
		out += "No accepted applications.\n\n"
	} else {
		acceptedItems := []string{}
		for _, app := range acceptedApps {
			task := getTask(app.TaskID)
			if task != nil {
				org := getOrganization(task.OrganizationID)
				if org != nil {
					status := getTaskStatusText(task.Status)
					acceptedItems = append(acceptedItems, md.Link(task.Title, realmPath+":task/"+strconv.Itoa(task.ID))+" at "+md.Link(org.Name, realmPath+":organization/"+strconv.Itoa(org.ID))+" - "+status)
				}
			}
		}
		out += md.BulletList(acceptedItems) + "\n\n"
	}

	// Rejected applications
	out += md.H3("❌ Rejected ("+strconv.Itoa(len(rejectedApps))+")") + "\n\n"
	if len(rejectedApps) == 0 {
		out += "No rejected applications.\n\n"
	} else {
		rejectedItems := []string{}
		for _, app := range rejectedApps {
			task := getTask(app.TaskID)
			if task != nil {
				org := getOrganization(task.OrganizationID)
				if org != nil {
					rejectedItems = append(rejectedItems, md.Link(task.Title, realmPath+":task/"+strconv.Itoa(task.ID))+" at "+md.Link(org.Name, realmPath+":organization/"+strconv.Itoa(org.ID)))
				}
			}
		}
		out += md.BulletList(rejectedItems) + "\n\n"
	}

	// Personal Kanban Board for assigned tasks
	out += md.H2("📋 Personal Kanban Board") + "\n\n"
	out += md.Link("View Full Kanban", realmPath+":user/"+addrStr+"/kanban") + "\n\n"
	out += renderUserKanbanPreview(addr)

	res.Write(out)
}

func userKanbanHandler(res *mux.ResponseWriter, req *mux.Request) {
	var out string

	addrStr := req.GetVar("addr")
	addr := std.Address(addrStr)

	// Get profile info
	name := profile.GetStringField(addr, "DisplayName", "Unknown")

	out += md.H1("📋 "+name+" - Kanban Board") + "\n\n"
	out += md.Link("← Back to Profile", realmPath+":user/"+addrStr) + "\n\n"

	// Full kanban board
	out += renderUserKanban(addr)

	// Admin actions if viewing own kanban
	caller := std.OriginCaller()
	if caller == addr {
		out += md.H2("⚙️ Kanban Actions") + "\n\n"
		out += md.Italic("Update kanban status for your assigned tasks:") + "\n\n"

		// List assigned tasks with update links
		tasks.Iterate("", "", func(key string, value interface{}) bool {
			task := value.(*Task)
			if task.Assignee == addr && task.Status == TaskAssigned {
				out += md.H3(task.Title) + "\n\n"
				out += md.Bold("Current Status:") + " " + getKanbanStatusText(task.KanbanStatus) + "\n\n"

				// Action links for kanban status
				todoLink := txlink.Call("UpdateKanbanStatus", strconv.Itoa(task.ID), "0")     // KanbanTodo
				progressLink := txlink.Call("UpdateKanbanStatus", strconv.Itoa(task.ID), "1") // KanbanInProgress
				reviewLink := txlink.Call("UpdateKanbanStatus", strconv.Itoa(task.ID), "2")   // KanbanReview
				doneLink := txlink.Call("UpdateKanbanStatus", strconv.Itoa(task.ID), "3")     // KanbanDone
				completeLink := txlink.Call("CompleteTask", strconv.Itoa(task.ID))

				actionItems := []string{
					md.Link("📝 Todo", todoLink),
					md.Link("🔄 In Progress", progressLink),
					md.Link("👀 Review", reviewLink),
					md.Link("✅ Done", doneLink),
					md.Link("🎉 Complete Task", completeLink),
				}

				out += md.Bold("Update Status:") + "\n"
				out += md.BulletList(actionItems) + "\n\n"
			}
			return false
		})
	}

	res.Write(out)
}

func organizationsHandler(res *mux.ResponseWriter, req *mux.Request) {
	var out string

	out += md.H1("🏢 All Organizations") + "\n\n"
	out += md.Link("← Back to Home", realmPath) + "\n\n"

	orgCount := organizations.Size()
	if orgCount == 0 {
		out += md.Bold("No organizations yet.") + "\n\n"
		out += "Be the first to create one!\n\n"
		out += md.Link("Create First Organization", realmPath+":organization/create") + "\n\n"
		res.Write(out)
		return
	}

	out += md.Bold("Total Organizations:") + " " + strconv.Itoa(orgCount) + "\n\n"

	organizations.Iterate("", "", func(key string, value interface{}) bool {
		org := value.(*Organization)

		adminName := profile.GetStringField(org.Admin, "DisplayName", "Unknown")

		out += md.HorizontalRule() + "\n\n"
		out += md.H3(md.Link(org.Name, realmPath+":organization/"+strconv.Itoa(org.ID))) + "\n\n"

		if org.Avatar != "" {
			out += "![Avatar](" + org.Avatar + ")\n\n"
		}

		orgInfoItems := []string{
			md.Bold("Domain:") + " @" + org.Domain,
			md.Bold("Admin:") + " " + adminName + " (`" + org.Admin.String() + "`)",
			md.Bold("Tasks:") + " " + strconv.Itoa(len(org.Tasks)),
		}

		if org.Bio != "" {
			orgInfoItems = append(orgInfoItems, md.Bold("Bio:")+" "+org.Bio)
		}

		if org.Website != "" {
			orgInfoItems = append(orgInfoItems, md.Bold("Website:")+" "+md.Link(org.Website, org.Website))
		}

		out += md.BulletList(orgInfoItems) + "\n\n"
		return false
	})

	res.Write(out)
}

func organizationHandler(res *mux.ResponseWriter, req *mux.Request) {
	var out string

	orgIDStr := req.GetVar("id")
	orgID, err := strconv.Atoi(orgIDStr)
	if err != nil {
		out += md.H1("❌ Error") + "\n\n"
		out += "Invalid organization ID: " + orgIDStr + "\n"
		res.Write(out)
		return
	}

	org := getOrganization(orgID)
	if org == nil {
		out += md.H1("❌ Not Found") + "\n\n"
		out += "Organization #" + orgIDStr + " not found.\n\n"
		out += md.Link("← Back to Organizations", realmPath+":organizations") + "\n"
		res.Write(out)
		return
	}

	out += md.H1("🏢 "+org.Name) + "\n\n"
	out += md.Link("← Back to Organizations", realmPath+":organizations") + "\n\n"

	if org.Avatar != "" {
		out += "![Avatar](" + org.Avatar + ")\n\n"
	}

	adminName := profile.GetStringField(org.Admin, "DisplayName", "Unknown")

	orgDetailsItems := []string{
		md.Bold("Domain:") + " @" + org.Domain,
		md.Bold("Admin:") + " " + adminName + " (`" + org.Admin.String() + "`)",
	}

	if org.Bio != "" {
		orgDetailsItems = append(orgDetailsItems, md.Bold("Bio:")+" "+org.Bio)
	}

	if org.Website != "" {
		orgDetailsItems = append(orgDetailsItems, md.Bold("Website:")+" "+md.Link(org.Website, org.Website))
	}

	out += md.BulletList(orgDetailsItems) + "\n\n"

	// Tasks
	out += md.H2("📋 Tasks ("+strconv.Itoa(len(org.Tasks))+")") + "\n\n"

	if len(org.Tasks) == 0 {
		out += "No tasks yet.\n\n"
	} else {
		taskItems := []string{}
		for _, taskID := range org.Tasks {
			task := getTask(taskID)
			if task != nil {
				status := getTaskStatusText(task.Status)
				taskItems = append(taskItems, md.Link(task.Title, realmPath+":task/"+strconv.Itoa(task.ID))+" - "+status)
			}
		}
		out += md.BulletList(taskItems) + "\n\n"
	}

	caller := std.OriginCaller()
	if caller == org.Admin {
		out += md.H2("⚙️ Admin Actions") + "\n\n"

		createTaskLink := txlink.Call("CreateTask",
			strconv.Itoa(org.ID), // orgID
			"",                   // title
			"",                   // description
			"")                   // reward

		adminActionItems := []string{
			md.Link("Create New Task", createTaskLink),
			"Edit Organization (coming soon)",
		}

		out += md.BulletList(adminActionItems) + "\n\n"

		// Show pending applications for this organization's tasks
		pendingApps := []*Application{}
		for _, taskID := range org.Tasks {
			task := getTask(taskID)
			if task != nil {
				for _, appID := range task.Applications {
					app := getApplication(appID)
					if app != nil && app.Status == AppPending {
						pendingApps = append(pendingApps, app)
					}
				}
			}
		}

		if len(pendingApps) > 0 {
			out += md.H3("📨 Pending Applications ("+strconv.Itoa(len(pendingApps))+")") + "\n\n"

			for _, app := range pendingApps {
				task := getTask(app.TaskID)
				if task != nil {
					applicantName := profile.GetStringField(app.Applicant, "DisplayName", "Unknown")

					out += md.HorizontalRule() + "\n\n"

					appInfoItems := []string{
						md.Bold("Task:") + " " + md.Link(task.Title, realmPath+":task/"+strconv.Itoa(task.ID)),
						md.Bold("Applicant:") + " " + md.Link(applicantName, realmPath+":user/"+app.Applicant.String()),
						md.Bold("Applied:") + " Block #" + strconv.FormatInt(app.AppliedAt, 10),
					}

					if app.Message != "" {
						appInfoItems = append(appInfoItems, md.Bold("Message:")+" "+app.Message)
					}

					out += md.BulletList(appInfoItems) + "\n\n"

					acceptLink := txlink.Call("AcceptApplication", strconv.Itoa(app.ID))
					rejectLink := txlink.Call("RejectApplication", strconv.Itoa(app.ID))

					actionItems := []string{
						md.Link("✅ Accept", acceptLink),
						md.Link("❌ Reject", rejectLink),
					}

					out += md.Bold("Actions:") + "\n"
					out += md.BulletList(actionItems) + "\n\n"
				}
			}
		}

		// Organization Kanban Board
		out += md.H3("📋 Organization Kanban Board") + "\n\n"
		out += md.Link("View Full Kanban", realmPath+":organization/"+strconv.Itoa(org.ID)+"/kanban") + "\n\n"
		out += renderOrganizationKanbanPreview(org)
	}

	res.Write(out)
}

func organizationKanbanHandler(res *mux.ResponseWriter, req *mux.Request) {
	var out string

	orgIDStr := req.GetVar("id")
	orgID, err := strconv.Atoi(orgIDStr)
	if err != nil {
		out += md.H1("❌ Error") + "\n\n"
		out += "Invalid organization ID: " + orgIDStr + "\n"
		res.Write(out)
		return
	}

	org := getOrganization(orgID)
	if org == nil {
		out += md.H1("❌ Not Found") + "\n\n"
		out += "Organization #" + orgIDStr + " not found.\n\n"
		res.Write(out)
		return
	}

	out += md.H1("📋 "+org.Name+" - Kanban Board") + "\n\n"
	out += md.Link("← Back to Organization", realmPath+":organization/"+orgIDStr) + "\n\n"

	// Full kanban board for organization
	out += renderOrganizationKanban(org)

	res.Write(out)
}

func CreateOrganization(cur realm, name, domain, bio, website, avatar string) {
	caller := std.OriginCaller()

	if name == "" || domain == "" {
		panic("Name and domain are required")
	}

	userName := profile.GetStringField(caller, "DisplayName", "")
	if userName == "" {
		panic("You need a profile first")
	}

	orgCounter++
	org := &Organization{
		ID:        orgCounter,
		Name:      name,
		Avatar:    avatar,
		Domain:    domain,
		Bio:       bio,
		Website:   website,
		Admin:     caller,
		Tasks:     []int{},
		CreatedAt: std.ChainHeight(),
	}

	organizations.Set(strconv.Itoa(orgCounter), org)
}

func CreateTask(cur realm, orgIDStr, title, description, reward string) {
	caller := std.OriginCaller()

	if orgIDStr == "" || title == "" || description == "" {
		panic("Organization ID, title and description are required")
	}

	orgID, err := strconv.Atoi(orgIDStr)
	if err != nil {
		panic("Invalid organization ID")
	}

	org := getOrganization(orgID)
	if org == nil {
		panic("Organization not found")
	}

	if org.Admin != caller {
		panic("Only organization admin can create tasks")
	}

	taskCounter++
	task := &Task{
		ID:             taskCounter,
		OrganizationID: orgID,
		Title:          title,
		Description:    description,
		Reward:         reward,
		Status:         TaskOpen,
		Assignee:       "",
		Applications:   []int{},
		CreatedAt:      std.ChainHeight(),
		KanbanStatus:   KanbanTodo, // Default kanban status
	}

	tasks.Set(strconv.Itoa(taskCounter), task)

	// Add task to organization
	org.Tasks = append(org.Tasks, taskCounter)
	organizations.Set(strconv.Itoa(orgID), org)
}

func ApplyToTask(cur realm, taskIDStr, message string) {
	caller := std.OriginCaller()

	if taskIDStr == "" {
		panic("Task ID is required")
	}

	taskID, err := strconv.Atoi(taskIDStr)
	if err != nil {
		panic("Invalid task ID")
	}

	task := getTask(taskID)
	if task == nil {
		panic("Task not found")
	}

	if task.Status != TaskOpen {
		panic("Task is not open for applications")
	}

	// Check if user already applied
	for _, appID := range task.Applications {
		app := getApplication(appID)
		if app != nil && app.Applicant == caller {
			panic("You have already applied for this task")
		}
	}

	// Create application
	appCounter++
	application := &Application{
		ID:        appCounter,
		TaskID:    taskID,
		Applicant: caller,
		Message:   message,
		Status:    AppPending,
		AppliedAt: std.ChainHeight(),
	}

	applications.Set(strconv.Itoa(appCounter), application)

	// Add application to task
	task.Applications = append(task.Applications, appCounter)
	tasks.Set(strconv.Itoa(taskID), task)
}

func AcceptApplication(cur realm, appIDStr string) {
	caller := std.OriginCaller()

	if appIDStr == "" {
		panic("Application ID is required")
	}

	appID, err := strconv.Atoi(appIDStr)
	if err != nil {
		panic("Invalid application ID")
	}

	app := getApplication(appID)
	if app == nil {
		panic("Application not found")
	}

	task := getTask(app.TaskID)
	if task == nil {
		panic("Task not found")
	}

	org := getOrganization(task.OrganizationID)
	if org == nil {
		panic("Organization not found")
	}

	if org.Admin != caller {
		panic("Only organization admin can accept applications")
	}

	if app.Status != AppPending {
		panic("Application is not pending")
	}

	// Accept application
	app.Status = AppAccepted
	applications.Set(strconv.Itoa(appID), app)

	// Assign task
	task.Status = TaskAssigned
	task.Assignee = app.Applicant
	task.KanbanStatus = KanbanTodo // Reset to todo when assigned
	tasks.Set(strconv.Itoa(app.TaskID), task)

	// Reject other pending applications
	for _, otherAppID := range task.Applications {
		if otherAppID != appID {
			otherApp := getApplication(otherAppID)
			if otherApp != nil && otherApp.Status == AppPending {
				otherApp.Status = AppRejected
				applications.Set(strconv.Itoa(otherAppID), otherApp)
			}
		}
	}
}

func RejectApplication(cur realm, appIDStr string) {
	caller := std.OriginCaller()

	if appIDStr == "" {
		panic("Application ID is required")
	}

	appID, err := strconv.Atoi(appIDStr)
	if err != nil {
		panic("Invalid application ID")
	}

	app := getApplication(appID)
	if app == nil {
		panic("Application not found")
	}

	task := getTask(app.TaskID)
	if task == nil {
		panic("Task not found")
	}

	org := getOrganization(task.OrganizationID)
	if org == nil {
		panic("Organization not found")
	}

	if org.Admin != caller {
		panic("Only organization admin can reject applications")
	}

	if app.Status != AppPending {
		panic("Application is not pending")
	}

	// Reject application
	app.Status = AppRejected
	applications.Set(strconv.Itoa(appID), app)
}

func CompleteTask(cur realm, taskIDStr string) {
	caller := std.OriginCaller()

	if taskIDStr == "" {
		panic("Task ID is required")
	}

	taskID, err := strconv.Atoi(taskIDStr)
	if err != nil {
		panic("Invalid task ID")
	}

	task := getTask(taskID)
	if task == nil {
		panic("Task not found")
	}

	if task.Status != TaskAssigned {
		panic("Task is not assigned")
	}

	if task.Assignee != caller {
		panic("Only assignee can complete task")
	}

	task.Status = TaskCompleted
	task.KanbanStatus = KanbanDone
	tasks.Set(strconv.Itoa(taskID), task)
}

func UpdateKanbanStatus(cur realm, taskIDStr, statusStr string) {
	caller := std.OriginCaller()

	if taskIDStr == "" || statusStr == "" {
		panic("Task ID and status are required")
	}

	taskID, err := strconv.Atoi(taskIDStr)
	if err != nil {
		panic("Invalid task ID")
	}

	statusInt, err := strconv.Atoi(statusStr)
	if err != nil {
		panic("Invalid status")
	}

	if statusInt < 0 || statusInt > 3 {
		panic("Invalid kanban status")
	}

	task := getTask(taskID)
	if task == nil {
		panic("Task not found")
	}

	if task.Assignee != caller {
		panic("Only assignee can update kanban status")
	}

	task.KanbanStatus = KanbanStatus(statusInt)
	tasks.Set(strconv.Itoa(taskID), task)
}

// Helper functions
func getOrganization(orgID int) *Organization {
	orgI, ok := organizations.Get(strconv.Itoa(orgID))
	if !ok {
		return nil
	}
	return orgI.(*Organization)
}

func getTask(taskID int) *Task {
	taskI, ok := tasks.Get(strconv.Itoa(taskID))
	if !ok {
		return nil
	}
	return taskI.(*Task)
}

func getApplication(appID int) *Application {
	appI, ok := applications.Get(strconv.Itoa(appID))
	if !ok {
		return nil
	}
	return appI.(*Application)
}

func getUserOrganizations(addr std.Address) []*Organization {
	var userOrgs []*Organization

	organizations.Iterate("", "", func(key string, value interface{}) bool {
		org := value.(*Organization)
		if org.Admin == addr {
			userOrgs = append(userOrgs, org)
		}
		return false
	})

	return userOrgs
}

func getTaskStatusText(status TaskStatus) string {
	switch status {
	case TaskOpen:
		return "🟢 Open"
	case TaskAssigned:
		return "🟡 Assigned"
	case TaskCompleted:
		return "✅ Completed"
	default:
		return "Unknown"
	}
}

func getApplicationStatusText(status ApplicationStatus) string {
	switch status {
	case AppPending:
		return "⏳ Pending"
	case AppAccepted:
		return "✅ Accepted"
	case AppRejected:
		return "❌ Rejected"
	default:
		return "Unknown"
	}
}

func getKanbanStatusText(status KanbanStatus) string {
	switch status {
	case KanbanTodo:
		return "📝 Todo"
	case KanbanInProgress:
		return "🔄 In Progress"
	case KanbanReview:
		return "👀 Review"
	case KanbanDone:
		return "✅ Done"
	default:
		return "Unknown"
	}
}

func renderUserKanbanPreview(addr std.Address) string {
	var b strings.Builder

	// Collect user's assigned tasks
	var userTasks []*Task
	tasks.Iterate("", "", func(key string, value interface{}) bool {
		task := value.(*Task)
		if task.Assignee == addr {
			userTasks = append(userTasks, task)
		}
		return false
	})

	if len(userTasks) == 0 {
		b.WriteString("No assigned tasks yet.\n\n")
		return b.String()
	}

	b.WriteString("**Assigned Tasks:** " + strconv.Itoa(len(userTasks)) + "\n\n")

	// Count by status for preview
	todoCount := 0
	progressCount := 0
	reviewCount := 0
	doneCount := 0

	for _, task := range userTasks {
		switch task.KanbanStatus {
		case KanbanTodo:
			todoCount++
		case KanbanInProgress:
			progressCount++
		case KanbanReview:
			reviewCount++
		case KanbanDone:
			doneCount++
		}
	}

	b.WriteString("📝 Todo: " + strconv.Itoa(todoCount) + " | ")
	b.WriteString("🔄 In Progress: " + strconv.Itoa(progressCount) + " | ")
	b.WriteString("👀 Review: " + strconv.Itoa(reviewCount) + " | ")
	b.WriteString("✅ Done: " + strconv.Itoa(doneCount) + "\n\n")

	return b.String()
}

func renderUserKanban(addr std.Address) string {
	var b strings.Builder

	// Collect user's assigned tasks
	var userTasks []*Task
	tasks.Iterate("", "", func(key string, value interface{}) bool {
		task := value.(*Task)
		if task.Assignee == addr {
			userTasks = append(userTasks, task)
		}
		return false
	})

	if len(userTasks) == 0 {
		b.WriteString("No assigned tasks yet.\n\n")
		return b.String()
	}

	// Organize by kanban status
	todoTasks := []*Task{}
	inProgressTasks := []*Task{}
	reviewTasks := []*Task{}
	doneTasks := []*Task{}

	for _, task := range userTasks {
		switch task.KanbanStatus {
		case KanbanTodo:
			todoTasks = append(todoTasks, task)
		case KanbanInProgress:
			inProgressTasks = append(inProgressTasks, task)
		case KanbanReview:
			reviewTasks = append(reviewTasks, task)
		case KanbanDone:
			doneTasks = append(doneTasks, task)
		}
	}

	// Render kanban columns
	b.WriteString("| 📝 Todo (" + strconv.Itoa(len(todoTasks)) + ") | 🔄 In Progress (" + strconv.Itoa(len(inProgressTasks)) + ") | 👀 Review (" + strconv.Itoa(len(reviewTasks)) + ") | ✅ Done (" + strconv.Itoa(len(doneTasks)) + ") |\n")
	b.WriteString("|---------|------------------|----------|----------|\n")

	maxRows := max(max(len(todoTasks), len(inProgressTasks)), max(len(reviewTasks), len(doneTasks)))

	for i := 0; i < maxRows; i++ {
		b.WriteString("| ")

		// Todo column
		if i < len(todoTasks) {
			task := todoTasks[i]
			org := getOrganization(task.OrganizationID)
			orgName := "Unknown"
			if org != nil {
				orgName = org.Name
			}
			b.WriteString("[" + task.Title + "](" + realmPath + ":task/" + strconv.Itoa(task.ID) + ") @ " + orgName)
		}
		b.WriteString(" | ")

		// In Progress column
		if i < len(inProgressTasks) {
			task := inProgressTasks[i]
			org := getOrganization(task.OrganizationID)
			orgName := "Unknown"
			if org != nil {
				orgName = org.Name
			}
			b.WriteString("[" + task.Title + "](" + realmPath + ":task/" + strconv.Itoa(task.ID) + ") @ " + orgName)
		}
		b.WriteString(" | ")

		// Review column
		if i < len(reviewTasks) {
			task := reviewTasks[i]
			org := getOrganization(task.OrganizationID)
			orgName := "Unknown"
			if org != nil {
				orgName = org.Name
			}
			b.WriteString("[" + task.Title + "](" + realmPath + ":task/" + strconv.Itoa(task.ID) + ") @ " + orgName)
		}
		b.WriteString(" | ")

		// Done column
		if i < len(doneTasks) {
			task := doneTasks[i]
			org := getOrganization(task.OrganizationID)
			orgName := "Unknown"
			if org != nil {
				orgName = org.Name
			}
			b.WriteString("[" + task.Title + "](" + realmPath + ":task/" + strconv.Itoa(task.ID) + ") @ " + orgName)
		}
		b.WriteString(" |\n")
	}

	b.WriteString("\n")
	return b.String()
}

func renderOrganizationKanbanPreview(org *Organization) string {
	var out string

	if len(org.Tasks) == 0 {
		out += "No tasks yet.\n\n"
		return out
	}

	// Count by status for preview
	openCount := 0
	assignedCount := 0
	completedCount := 0

	for _, taskID := range org.Tasks {
		task := getTask(taskID)
		if task != nil {
			switch task.Status {
			case TaskOpen:
				openCount++
			case TaskAssigned:
				assignedCount++
			case TaskCompleted:
				completedCount++
			}
		}
	}

	out += md.Bold("Total Tasks:") + " " + strconv.Itoa(len(org.Tasks)) + "\n\n"

	statusSummary := []string{
		"🟢 Open: " + strconv.Itoa(openCount),
		"🟡 Assigned: " + strconv.Itoa(assignedCount),
		"✅ Completed: " + strconv.Itoa(completedCount),
	}

	out += strings.Join(statusSummary, " | ") + "\n\n"

	return out
}

func renderOrganizationKanban(org *Organization) string {
	var out string

	if len(org.Tasks) == 0 {
		out += "No tasks yet.\n\n"
		return out
	}

	// Organize by status
	openTasks := []*Task{}
	assignedTasks := []*Task{}
	completedTasks := []*Task{}

	for _, taskID := range org.Tasks {
		task := getTask(taskID)
		if task != nil {
			switch task.Status {
			case TaskOpen:
				openTasks = append(openTasks, task)
			case TaskAssigned:
				assignedTasks = append(assignedTasks, task)
			case TaskCompleted:
				completedTasks = append(completedTasks, task)
			}
		}
	}

	// Render organization kanban
	out += "| 🟢 Open (" + strconv.Itoa(len(openTasks)) + ") | 🟡 Assigned (" + strconv.Itoa(len(assignedTasks)) + ") | ✅ Completed (" + strconv.Itoa(len(completedTasks)) + ") |\n"
	out += "|---------|------------|-------------|\n"

	maxRows := max(max(len(openTasks), len(assignedTasks)), len(completedTasks))

	for i := 0; i < maxRows; i++ {
		out += "| "

		// Open tasks column
		if i < len(openTasks) {
			task := openTasks[i]
			out += md.Link(task.Title, realmPath+":task/"+strconv.Itoa(task.ID)) + " (" + strconv.Itoa(len(task.Applications)) + " apps)"
		}
		out += " | "

		// Assigned tasks column
		if i < len(assignedTasks) {
			task := assignedTasks[i]
			assigneeName := profile.GetStringField(task.Assignee, "DisplayName", "Unknown")
			kanbanStatus := getKanbanStatusText(task.KanbanStatus)
			out += md.Link(task.Title, realmPath+":task/"+strconv.Itoa(task.ID)) + " by " + md.Link(assigneeName, realmPath+":user/"+task.Assignee.String()) + " - " + kanbanStatus
		}
		out += " | "

		// Completed tasks column
		if i < len(completedTasks) {
			task := completedTasks[i]
			assigneeName := profile.GetStringField(task.Assignee, "DisplayName", "Unknown")
			out += md.Link(task.Title, realmPath+":task/"+strconv.Itoa(task.ID)) + " by " + md.Link(assigneeName, realmPath+":user/"+task.Assignee.String())
		}
		out += " |\n"
	}

	out += "\n"
	return out
}

func renderTaskSummary(task *Task) string {
	org := getOrganization(task.OrganizationID)
	if org == nil {
		return ""
	}

	var out string
	out += md.HorizontalRule() + "\n\n"
	out += md.H3(md.Link(task.Title, realmPath+":task/"+strconv.Itoa(task.ID))) + "\n\n"

	infoItems := []string{
		md.Bold("Organization:") + " " + md.Link(org.Name, realmPath+":organization/"+strconv.Itoa(org.ID)),
		md.Bold("Status:") + " " + getTaskStatusText(task.Status),
	}

	if task.Reward != "" {
		infoItems = append(infoItems, md.Bold("Reward:")+" "+task.Reward)
	}

	if task.Assignee != "" {
		assigneeName := profile.GetStringField(task.Assignee, "DisplayName", "Unknown")
		infoItems = append(infoItems, md.Bold("Assignee:")+" "+assigneeName)
	}

	infoItems = append(infoItems, md.Bold("Applications:")+" "+strconv.Itoa(len(task.Applications)))

	out += md.BulletList(infoItems) + "\n"

	// Show truncated description
	description := task.Description
	if len(description) > 100 {
		description = description[:97] + "..."
	}
	out += md.Bold("Description:") + " " + description + "\n\n"

	return out
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
