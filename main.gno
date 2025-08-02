package kontribz

import (
	"std"
	"strconv"
	"strings"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/mux"
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
	var b strings.Builder
	b.WriteString("# 🎯 Kontribz - Bounty Manager\n\n")

	b.WriteString("## 📊 Platform Statistics\n\n")
	orgCount := organizations.Size()
	taskCount := tasks.Size()
	appCount := applications.Size()
	b.WriteString("- **Organizations:** " + strconv.Itoa(orgCount) + "\n")
	b.WriteString("- **Tasks:** " + strconv.Itoa(taskCount) + "\n")
	b.WriteString("- **Applications:** " + strconv.Itoa(appCount) + "\n\n")

	b.WriteString("## 🚀 Quick Actions\n\n")
	b.WriteString("- [Create Your Profile](" + realmPath + ":profile/create) - Start by creating your user profile\n")
	b.WriteString("- [Create Organization](" + realmPath + ":organization/create) - Create your organization\n")
	b.WriteString("- [Browse Organizations](" + realmPath + ":organizations) - View all organizations\n")
	b.WriteString("- [Browse Tasks](" + realmPath + ":tasks) - View all tasks\n")
	b.WriteString("- [Browse Users](" + realmPath + ":users) - View all users\n\n")

	res.Write(b.String())
}

func profileCreateHandler(res *mux.ResponseWriter, req *mux.Request) {
	var b strings.Builder
	b.WriteString("# 👤 Create Profile\n\n")
	b.WriteString("Click the link below to connect and set up your profile:\n\n")

	connectionLink := txlink.Realm("gno.land/r/demo/profile").Call("SetStringField", "DisplayName", "New User")
	b.WriteString("🔗 [**Connexion**](" + connectionLink + ")\n\n")

	b.WriteString("*This will create a basic profile with the display name 'New User'.*\n\n")

	res.Write(b.String())
}

func organizationCreateHandler(res *mux.ResponseWriter, req *mux.Request) {
	var b strings.Builder

	b.WriteString("# 🏢 Create Organization\n\n")
	b.WriteString("[← Back to Home](" + realmPath + ")\n\n")

	b.WriteString("Create your organization to manage bounties and tasks.\n\n")

	b.WriteString("## Organization Form\n\n")
	b.WriteString("To create your organization, you can call the `CreateOrganization` function or use these quick templates:\n\n")

	b.WriteString("### 🚀 Quick Templates\n\n")

	createOrgLink := txlink.Call("CreateOrganization", "name", "", "domain", "", "bio", "", "website", "", "avatar", "")
	b.WriteString("**Create your organizations:** [Create](" + createOrgLink + ")\n\n")

	b.WriteString("**Parameters:**\n")
	b.WriteString("- **Name** (required): Organization name\n")
	b.WriteString("- **Domain** (required): Unique domain/handle\n")
	b.WriteString("- **Bio** (optional): Organization description\n")
	b.WriteString("- **Website** (optional): Organization website\n")
	b.WriteString("- **Avatar** (optional): Organization avatar URL\n\n")

	res.Write(b.String())
}

func taskCreateHandler(res *mux.ResponseWriter, req *mux.Request) {
	var b strings.Builder

	b.WriteString("# 📝 Create Task\n\n")
	b.WriteString("[← Back to Home](" + realmPath + ")\n\n")

	caller := std.OriginCaller()

	// Get user's organizations
	userOrgs := getUserOrganizations(caller)

	if len(userOrgs) == 0 {
		b.WriteString("## ❌ No Organizations Found\n\n")
		b.WriteString("You need to be an admin of at least one organization to create tasks.\n\n")
		b.WriteString("[Create Organization](" + realmPath + ":organization/create)\n\n")
		res.Write(b.String())
		return
	}

	b.WriteString("Create a new task/bounty for one of your organizations.\n\n")

	b.WriteString("## Your Organizations\n\n")
	for _, org := range userOrgs {
		b.WriteString("### " + org.Name + " (ID: " + strconv.Itoa(org.ID) + ")\n\n")

		createTaskLink := txlink.Call("CreateTask",
			strconv.Itoa(org.ID), // orgID
			"",                   // title
			"",                   // description
			"")                   // reward

		b.WriteString("**Create task for this organization:** [Create Task](" + createTaskLink + ")\n\n")
	}

	b.WriteString("## Task Parameters\n\n")
	b.WriteString("When creating a task, you need to provide:\n")
	b.WriteString("- **Organization ID** (required): ID of your organization\n")
	b.WriteString("- **Title** (required): Task title\n")
	b.WriteString("- **Description** (required): Task description\n")
	b.WriteString("- **Reward** (optional): Reward for completing the task\n\n")

	res.Write(b.String())
}

func tasksHandler(res *mux.ResponseWriter, req *mux.Request) {
	var b strings.Builder

	b.WriteString("# 📋 All Tasks\n\n")
	b.WriteString("[← Back to Home](" + realmPath + ")\n\n")

	taskCount := tasks.Size()
	if taskCount == 0 {
		b.WriteString("**No tasks yet.**\n\n")
		b.WriteString("Organizations can create tasks for their bounties.\n\n")
		b.WriteString("[Create First Task](" + realmPath + ":task/create)\n\n")
		res.Write(b.String())
		return
	}

	b.WriteString("**Total Tasks:** " + strconv.Itoa(taskCount) + "\n\n")

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
	b.WriteString("## 🟢 Open Tasks (" + strconv.Itoa(len(openTasks)) + ")\n\n")
	if len(openTasks) == 0 {
		b.WriteString("No open tasks.\n\n")
	} else {
		for _, task := range openTasks {
			renderTaskSummary(&b, task)
		}
	}

	// Display assigned tasks
	b.WriteString("## 🟡 Assigned Tasks (" + strconv.Itoa(len(assignedTasks)) + ")\n\n")
	if len(assignedTasks) == 0 {
		b.WriteString("No assigned tasks.\n\n")
	} else {
		for _, task := range assignedTasks {
			renderTaskSummary(&b, task)
		}
	}

	// Display completed tasks
	b.WriteString("## ✅ Completed Tasks (" + strconv.Itoa(len(completedTasks)) + ")\n\n")
	if len(completedTasks) == 0 {
		b.WriteString("No completed tasks.\n\n")
	} else {
		for _, task := range completedTasks {
			renderTaskSummary(&b, task)
		}
	}

	res.Write(b.String())
}

func taskHandler(res *mux.ResponseWriter, req *mux.Request) {
	var b strings.Builder

	taskIDStr := req.GetVar("id")
	taskID, err := strconv.Atoi(taskIDStr)
	if err != nil {
		b.WriteString("# ❌ Error\n\n")
		b.WriteString("Invalid task ID: " + taskIDStr + "\n")
		res.Write(b.String())
		return
	}

	task := getTask(taskID)
	if task == nil {
		b.WriteString("# ❌ Not Found\n\n")
		b.WriteString("Task #" + taskIDStr + " not found.\n\n")
		b.WriteString("[← Back to Tasks](" + realmPath + ":tasks)\n")
		res.Write(b.String())
		return
	}

	org := getOrganization(task.OrganizationID)
	if org == nil {
		b.WriteString("# ❌ Error\n\n")
		b.WriteString("Organization not found for this task.\n")
		res.Write(b.String())
		return
	}

	b.WriteString("# 📝 " + task.Title + "\n\n")
	b.WriteString("[← Back to Tasks](" + realmPath + ":tasks) | ")
	b.WriteString("[View Organization](" + realmPath + ":organization/" + strconv.Itoa(org.ID) + ")\n\n")

	// Task info
	b.WriteString("**Organization:** [" + org.Name + "](" + realmPath + ":organization/" + strconv.Itoa(org.ID) + ")\n")
	b.WriteString("**Status:** " + getTaskStatusText(task.Status) + "\n")

	if task.Reward != "" {
		b.WriteString("**Reward:** " + task.Reward + "\n")
	}

	if task.Assignee != "" {
		assigneeName := profile.GetStringField(task.Assignee, "DisplayName", "Unknown")
		b.WriteString("**Assignee:** " + assigneeName + " (`" + task.Assignee.String() + "`)\n")
		b.WriteString("**Kanban Status:** " + getKanbanStatusText(task.KanbanStatus) + "\n")
	}

	b.WriteString("**Created:** Block #" + strconv.FormatInt(task.CreatedAt, 10) + "\n\n")

	b.WriteString("## Description\n\n")
	b.WriteString(task.Description + "\n\n")

	// Applications section
	b.WriteString("## 📨 Applications (" + strconv.Itoa(len(task.Applications)) + ")\n\n")

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
			b.WriteString("### 🙋 Apply for this task\n\n")

			applyLink := txlink.Call("ApplyToTask",
				strconv.Itoa(task.ID), // taskID
				"")                    // message

			b.WriteString("**Apply for this task:** [Apply](" + applyLink + ")\n\n")
			b.WriteString("*Note: You can provide a message explaining why you're the right person for this task.*\n\n")
		} else {
			b.WriteString("**✅ You have already applied for this task.**\n\n")
		}
	}

	// Show applications
	if len(task.Applications) == 0 {
		b.WriteString("No applications yet.\n\n")
	} else {
		for _, appID := range task.Applications {
			app := getApplication(appID)
			if app != nil {
				status := getApplicationStatusText(app.Status)
				applicantName := profile.GetStringField(app.Applicant, "DisplayName", "Unknown")

				b.WriteString("---\n\n")
				b.WriteString("**Applicant:** " + applicantName + " (`" + app.Applicant.String() + "`)\n")
				b.WriteString("**Status:** " + status + "\n")
				b.WriteString("**Applied:** Block #" + strconv.FormatInt(app.AppliedAt, 10) + "\n")

				if app.Message != "" {
					b.WriteString("**Message:** " + app.Message + "\n")
				}

				// Admin actions for pending applications
				if caller == org.Admin && app.Status == AppPending {
					b.WriteString("\n**Admin Actions:**\n")
					b.WriteString("*Go to your [organization page](" + realmPath + ":organization/" + strconv.Itoa(org.ID) + ") to accept or reject applications.*\n")
				}

				b.WriteString("\n")
			}
		}
	}

	// Admin actions
	if caller == org.Admin {
		b.WriteString("## ⚙️ Admin Actions\n\n")
		if task.Status == TaskOpen {
			b.WriteString("- Review applications above to assign this task\n")
		} else if task.Status == TaskAssigned {
			b.WriteString("- Task is currently assigned to " + profile.GetStringField(task.Assignee, "DisplayName", "Unknown") + "\n")
		}
		b.WriteString("- Edit Task (coming soon)\n")
		b.WriteString("- Delete Task (coming soon)\n\n")
	}

	res.Write(b.String())
}

func usersHandler(res *mux.ResponseWriter, req *mux.Request) {
	var b strings.Builder

	b.WriteString("# 👥 All Users\n\n")
	b.WriteString("[← Back to Home](" + realmPath + ")\n\n")

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
		b.WriteString("**No users found yet.**\n\n")
		b.WriteString("Users will appear here as they create organizations, apply to tasks, or get assigned to tasks.\n\n")
		res.Write(b.String())
		return
	}

	b.WriteString("**Total Users:** " + strconv.Itoa(len(userSet)) + "\n\n")

	// Display users
	for addrStr := range userSet {
		addr := std.Address(addrStr)
		name := profile.GetStringField(addr, "DisplayName", "Unknown")

		b.WriteString("---\n\n")
		b.WriteString("### [" + name + "](" + realmPath + ":user/" + addrStr + ")\n\n")
		b.WriteString("**Address:** `" + addrStr + "`\n")

		// Count user's organizations
		userOrgs := getUserOrganizations(addr)
		b.WriteString("**Organizations:** " + strconv.Itoa(len(userOrgs)) + "\n")

		// Count user's applications
		userAppCount := 0
		applications.Iterate("", "", func(key string, value interface{}) bool {
			app := value.(*Application)
			if app.Applicant == addr {
				userAppCount++
			}
			return false
		})
		b.WriteString("**Applications:** " + strconv.Itoa(userAppCount) + "\n")

		// Count assigned tasks
		assignedTaskCount := 0
		tasks.Iterate("", "", func(key string, value interface{}) bool {
			task := value.(*Task)
			if task.Assignee == addr {
				assignedTaskCount++
			}
			return false
		})
		b.WriteString("**Assigned Tasks:** " + strconv.Itoa(assignedTaskCount) + "\n\n")
	}

	res.Write(b.String())
}

func userHandler(res *mux.ResponseWriter, req *mux.Request) {
	var b strings.Builder

	addrStr := req.GetVar("addr")
	addr := std.Address(addrStr)

	// Get profile info
	name := profile.GetStringField(addr, "DisplayName", "Unknown")

	b.WriteString("# 👤 " + name + "\n\n")
	b.WriteString("[← Back to Users](" + realmPath + ":users)\n\n")

	// Profile info
	b.WriteString("**Address:** `" + addrStr + "`\n\n")

	// User's organizations
	userOrgs := getUserOrganizations(addr)
	if len(userOrgs) > 0 {
		b.WriteString("## 🏢 Organizations (" + strconv.Itoa(len(userOrgs)) + ")\n\n")
		for _, org := range userOrgs {
			b.WriteString("- [" + org.Name + "](" + realmPath + ":organization/" + strconv.Itoa(org.ID) + ") - " + strconv.Itoa(len(org.Tasks)) + " tasks\n")
		}
		b.WriteString("\n")
	}

	// User's applications
	b.WriteString("## 📨 Applications\n\n")

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
	b.WriteString("### ⏳ Pending (" + strconv.Itoa(len(pendingApps)) + ")\n\n")
	if len(pendingApps) == 0 {
		b.WriteString("No pending applications.\n\n")
	} else {
		for _, app := range pendingApps {
			task := getTask(app.TaskID)
			if task != nil {
				org := getOrganization(task.OrganizationID)
				if org != nil {
					b.WriteString("- [" + task.Title + "](" + realmPath + ":task/" + strconv.Itoa(task.ID) + ") at [" + org.Name + "](" + realmPath + ":organization/" + strconv.Itoa(org.ID) + ")\n")
				}
			}
		}
		b.WriteString("\n")
	}

	// Accepted applications (assigned tasks)
	b.WriteString("### ✅ Accepted/Assigned (" + strconv.Itoa(len(acceptedApps)) + ")\n\n")
	if len(acceptedApps) == 0 {
		b.WriteString("No accepted applications.\n\n")
	} else {
		for _, app := range acceptedApps {
			task := getTask(app.TaskID)
			if task != nil {
				org := getOrganization(task.OrganizationID)
				if org != nil {
					status := getTaskStatusText(task.Status)
					b.WriteString("- [" + task.Title + "](" + realmPath + ":task/" + strconv.Itoa(task.ID) + ") at [" + org.Name + "](" + realmPath + ":organization/" + strconv.Itoa(org.ID) + ") - " + status + "\n")
				}
			}
		}
		b.WriteString("\n")
	}

	// Rejected applications
	b.WriteString("### ❌ Rejected (" + strconv.Itoa(len(rejectedApps)) + ")\n\n")
	if len(rejectedApps) == 0 {
		b.WriteString("No rejected applications.\n\n")
	} else {
		for _, app := range rejectedApps {
			task := getTask(app.TaskID)
			if task != nil {
				org := getOrganization(task.OrganizationID)
				if org != nil {
					b.WriteString("- [" + task.Title + "](" + realmPath + ":task/" + strconv.Itoa(task.ID) + ") at [" + org.Name + "](" + realmPath + ":organization/" + strconv.Itoa(org.ID) + ")\n")
				}
			}
		}
		b.WriteString("\n")
	}

	// Personal Kanban Board for assigned tasks
	b.WriteString("## 📋 Personal Kanban Board\n\n")
	b.WriteString("[View Full Kanban](" + realmPath + ":user/" + addrStr + "/kanban)\n\n")
	b.WriteString(renderUserKanbanPreview(addr))

	res.Write(b.String())
}

func userKanbanHandler(res *mux.ResponseWriter, req *mux.Request) {
	var b strings.Builder

	addrStr := req.GetVar("addr")
	addr := std.Address(addrStr)

	// Get profile info
	name := profile.GetStringField(addr, "DisplayName", "Unknown")

	b.WriteString("# 📋 " + name + " - Kanban Board\n\n")
	b.WriteString("[← Back to Profile](" + realmPath + ":user/" + addrStr + ")\n\n")

	// Full kanban board
	b.WriteString(renderUserKanban(addr))

	// Admin actions if viewing own kanban
	caller := std.OriginCaller()
	if caller == addr {
		b.WriteString("## ⚙️ Kanban Actions\n\n")
		b.WriteString("*Update kanban status for your assigned tasks:*\n\n")

		// List assigned tasks with update links
		tasks.Iterate("", "", func(key string, value interface{}) bool {
			task := value.(*Task)
			if task.Assignee == addr && task.Status == TaskAssigned {
				b.WriteString("### " + task.Title + "\n\n")
				b.WriteString("**Current Status:** " + getKanbanStatusText(task.KanbanStatus) + "\n\n")

				// Action links for kanban status
				todoLink := txlink.Call("UpdateKanbanStatus", strconv.Itoa(task.ID), "0")     // KanbanTodo
				progressLink := txlink.Call("UpdateKanbanStatus", strconv.Itoa(task.ID), "1") // KanbanInProgress
				reviewLink := txlink.Call("UpdateKanbanStatus", strconv.Itoa(task.ID), "2")   // KanbanReview
				doneLink := txlink.Call("UpdateKanbanStatus", strconv.Itoa(task.ID), "3")     // KanbanDone
				completeLink := txlink.Call("CompleteTask", strconv.Itoa(task.ID))

				b.WriteString("**Update Status:**\n")
				b.WriteString("- [📝 Todo](" + todoLink + ")\n")
				b.WriteString("- [🔄 In Progress](" + progressLink + ")\n")
				b.WriteString("- [👀 Review](" + reviewLink + ")\n")
				b.WriteString("- [✅ Done](" + doneLink + ")\n")
				b.WriteString("- [🎉 Complete Task](" + completeLink + ")\n\n")
			}
			return false
		})
	}

	res.Write(b.String())
}

func organizationsHandler(res *mux.ResponseWriter, req *mux.Request) {
	var b strings.Builder

	b.WriteString("# 🏢 All Organizations\n\n")
	b.WriteString("[← Back to Home](" + realmPath + ")\n\n")

	orgCount := organizations.Size()
	if orgCount == 0 {
		b.WriteString("**No organizations yet.**\n\n")
		b.WriteString("Be the first to create one!\n\n")
		b.WriteString("[Create First Organization](" + realmPath + ":organization/create)\n\n")
		res.Write(b.String())
		return
	}

	b.WriteString("**Total Organizations:** " + strconv.Itoa(orgCount) + "\n\n")

	organizations.Iterate("", "", func(key string, value interface{}) bool {
		org := value.(*Organization)

		adminName := profile.GetStringField(org.Admin, "DisplayName", "Unknown")

		b.WriteString("---\n\n")
		b.WriteString("### [" + org.Name + "](" + realmPath + ":organization/" + strconv.Itoa(org.ID) + ")\n\n")

		if org.Avatar != "" {
			b.WriteString("![Avatar](" + org.Avatar + ")\n\n")
		}

		b.WriteString("**Domain:** @" + org.Domain + "\n")
		b.WriteString("**Admin:** " + adminName + " (`" + org.Admin.String() + "`)\n")
		b.WriteString("**Tasks:** " + strconv.Itoa(len(org.Tasks)) + "\n")

		if org.Bio != "" {
			b.WriteString("**Bio:** " + org.Bio + "\n")
		}

		if org.Website != "" {
			b.WriteString("**Website:** [" + org.Website + "](" + org.Website + ")\n")
		}

		b.WriteString("\n")
		return false
	})

	res.Write(b.String())
}

func organizationHandler(res *mux.ResponseWriter, req *mux.Request) {
	var b strings.Builder

	orgIDStr := req.GetVar("id")
	orgID, err := strconv.Atoi(orgIDStr)
	if err != nil {
		b.WriteString("# ❌ Error\n\n")
		b.WriteString("Invalid organization ID: " + orgIDStr + "\n")
		res.Write(b.String())
		return
	}

	org := getOrganization(orgID)
	if org == nil {
		b.WriteString("# ❌ Not Found\n\n")
		b.WriteString("Organization #" + orgIDStr + " not found.\n\n")
		b.WriteString("[← Back to Organizations](" + realmPath + ":organizations)\n")
		res.Write(b.String())
		return
	}

	b.WriteString("# 🏢 " + org.Name + "\n\n")
	b.WriteString("[← Back to Organizations](" + realmPath + ":organizations)\n\n")

	if org.Avatar != "" {
		b.WriteString("![Avatar](" + org.Avatar + ")\n\n")
	}

	b.WriteString("**Domain:** @" + org.Domain + "\n")

	adminName := profile.GetStringField(org.Admin, "DisplayName", "Unknown")
	b.WriteString("**Admin:** " + adminName + " (`" + org.Admin.String() + "`)\n")

	if org.Bio != "" {
		b.WriteString("**Bio:** " + org.Bio + "\n")
	}

	if org.Website != "" {
		b.WriteString("**Website:** [" + org.Website + "](" + org.Website + ")\n")
	}

	// Tasks
	b.WriteString("\n## 📋 Tasks (" + strconv.Itoa(len(org.Tasks)) + ")\n\n")

	if len(org.Tasks) == 0 {
		b.WriteString("No tasks yet.\n\n")
	} else {
		for _, taskID := range org.Tasks {
			task := getTask(taskID)
			if task != nil {
				status := getTaskStatusText(task.Status)
				b.WriteString("- [" + task.Title + "](" + realmPath + ":task/" + strconv.Itoa(task.ID) + ") - " + status + "\n")
			}
		}
		b.WriteString("\n")
	}

	caller := std.OriginCaller()
	if caller == org.Admin {
		b.WriteString("## ⚙️ Admin Actions\n\n")

		createTaskLink := txlink.Call("CreateTask",
			strconv.Itoa(org.ID), // orgID
			"",                   // title
			"",                   // description
			"")                   // reward

		b.WriteString("- [Create New Task](" + createTaskLink + ")\n")
		b.WriteString("- Edit Organization (coming soon)\n\n")

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
			b.WriteString("### 📨 Pending Applications (" + strconv.Itoa(len(pendingApps)) + ")\n\n")

			for _, app := range pendingApps {
				task := getTask(app.TaskID)
				if task != nil {
					applicantName := profile.GetStringField(app.Applicant, "DisplayName", "Unknown")

					b.WriteString("---\n\n")
					b.WriteString("**Task:** [" + task.Title + "](" + realmPath + ":task/" + strconv.Itoa(task.ID) + ")\n")
					b.WriteString("**Applicant:** [" + applicantName + "](" + realmPath + ":user/" + app.Applicant.String() + ")\n")
					b.WriteString("**Applied:** Block #" + strconv.FormatInt(app.AppliedAt, 10) + "\n")

					if app.Message != "" {
						b.WriteString("**Message:** " + app.Message + "\n")
					}

					b.WriteString("\n**Actions:**\n")

					acceptLink := txlink.Call("AcceptApplication", strconv.Itoa(app.ID))
					rejectLink := txlink.Call("RejectApplication", strconv.Itoa(app.ID))

					b.WriteString("- [✅ Accept](" + acceptLink + ")\n")
					b.WriteString("- [❌ Reject](" + rejectLink + ")\n\n")
				}
			}
		}

		// Organization Kanban Board
		b.WriteString("### 📋 Organization Kanban Board\n\n")
		b.WriteString("[View Full Kanban](" + realmPath + ":organization/" + strconv.Itoa(org.ID) + "/kanban)\n\n")
		b.WriteString(renderOrganizationKanbanPreview(org))
	}

	res.Write(b.String())
}

func organizationKanbanHandler(res *mux.ResponseWriter, req *mux.Request) {
	var b strings.Builder

	orgIDStr := req.GetVar("id")
	orgID, err := strconv.Atoi(orgIDStr)
	if err != nil {
		b.WriteString("# ❌ Error\n\n")
		b.WriteString("Invalid organization ID: " + orgIDStr + "\n")
		res.Write(b.String())
		return
	}

	org := getOrganization(orgID)
	if org == nil {
		b.WriteString("# ❌ Not Found\n\n")
		b.WriteString("Organization #" + orgIDStr + " not found.\n\n")
		res.Write(b.String())
		return
	}

	b.WriteString("# 📋 " + org.Name + " - Kanban Board\n\n")
	b.WriteString("[← Back to Organization](" + realmPath + ":organization/" + orgIDStr + ")\n\n")

	// Full kanban board for organization
	b.WriteString(renderOrganizationKanban(org))

	res.Write(b.String())
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
	var b strings.Builder

	if len(org.Tasks) == 0 {
		b.WriteString("No tasks yet.\n\n")
		return b.String()
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

	b.WriteString("**Total Tasks:** " + strconv.Itoa(len(org.Tasks)) + "\n\n")
	b.WriteString("🟢 Open: " + strconv.Itoa(openCount) + " | ")
	b.WriteString("🟡 Assigned: " + strconv.Itoa(assignedCount) + " | ")
	b.WriteString("✅ Completed: " + strconv.Itoa(completedCount) + "\n\n")

	return b.String()
}

func renderOrganizationKanban(org *Organization) string {
	var b strings.Builder

	if len(org.Tasks) == 0 {
		b.WriteString("No tasks yet.\n\n")
		return b.String()
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
	b.WriteString("| 🟢 Open (" + strconv.Itoa(len(openTasks)) + ") | 🟡 Assigned (" + strconv.Itoa(len(assignedTasks)) + ") | ✅ Completed (" + strconv.Itoa(len(completedTasks)) + ") |\n")
	b.WriteString("|---------|------------|-------------|\n")

	maxRows := max(max(len(openTasks), len(assignedTasks)), len(completedTasks))

	for i := 0; i < maxRows; i++ {
		b.WriteString("| ")

		// Open tasks column
		if i < len(openTasks) {
			task := openTasks[i]
			b.WriteString("[" + task.Title + "](" + realmPath + ":task/" + strconv.Itoa(task.ID) + ") (" + strconv.Itoa(len(task.Applications)) + " apps)")
		}
		b.WriteString(" | ")

		// Assigned tasks column
		if i < len(assignedTasks) {
			task := assignedTasks[i]
			assigneeName := profile.GetStringField(task.Assignee, "DisplayName", "Unknown")
			kanbanStatus := getKanbanStatusText(task.KanbanStatus)
			b.WriteString("[" + task.Title + "](" + realmPath + ":task/" + strconv.Itoa(task.ID) + ") by [" + assigneeName + "](" + realmPath + ":user/" + task.Assignee.String() + ") - " + kanbanStatus)
		}
		b.WriteString(" | ")

		// Completed tasks column
		if i < len(completedTasks) {
			task := completedTasks[i]
			assigneeName := profile.GetStringField(task.Assignee, "DisplayName", "Unknown")
			b.WriteString("[" + task.Title + "](" + realmPath + ":task/" + strconv.Itoa(task.ID) + ") by [" + assigneeName + "](" + realmPath + ":user/" + task.Assignee.String() + ")")
		}
		b.WriteString(" |\n")
	}

	b.WriteString("\n")
	return b.String()
}

func renderTaskSummary(b *strings.Builder, task *Task) {
	org := getOrganization(task.OrganizationID)
	if org == nil {
		return
	}

	b.WriteString("---\n\n")
	b.WriteString("### [" + task.Title + "](" + realmPath + ":task/" + strconv.Itoa(task.ID) + ")\n\n")

	b.WriteString("**Organization:** [" + org.Name + "](" + realmPath + ":organization/" + strconv.Itoa(org.ID) + ")\n")
	b.WriteString("**Status:** " + getTaskStatusText(task.Status) + "\n")

	if task.Reward != "" {
		b.WriteString("**Reward:** " + task.Reward + "\n")
	}

	if task.Assignee != "" {
		assigneeName := profile.GetStringField(task.Assignee, "DisplayName", "Unknown")
		b.WriteString("**Assignee:** " + assigneeName + "\n")
	}

	b.WriteString("**Applications:** " + strconv.Itoa(len(task.Applications)) + "\n")

	// Show truncated description
	description := task.Description
	if len(description) > 100 {
		description = description[:97] + "..."
	}
	b.WriteString("**Description:** " + description + "\n\n")
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
