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
	orgCounter    int      // organization counter
	taskCounter   int      // task counter
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
	CreatedAt      int64
}

type TaskStatus int

const (
	TaskOpen TaskStatus = iota
	TaskAssigned
	TaskCompleted
)

func init() {
	router.HandleFunc("", homeHandler)
	router.HandleFunc("profile/create", profileCreateHandler)
	router.HandleFunc("organization/create", organizationCreateHandler)
	router.HandleFunc("organization/{id}", organizationHandler)
	router.HandleFunc("organizations", organizationsHandler)
	router.HandleFunc("task/create", taskCreateHandler)
	router.HandleFunc("task/{id}", taskHandler)
	router.HandleFunc("tasks", tasksHandler)
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
	b.WriteString("- **Organizations:** " + strconv.Itoa(orgCount) + "\n")
	b.WriteString("- **Tasks:** " + strconv.Itoa(taskCount) + "\n")
	b.WriteString("- **Applications:** 0\n\n")

	b.WriteString("## 🚀 Quick Actions\n\n")
	b.WriteString("- [Create Your Profile](" + realmPath + ":profile/create) - Start by creating your user profile\n")
	b.WriteString("- [Create Organization](" + realmPath + ":organization/create) - Create your organization\n")
	b.WriteString("- [Browse Organizations](" + realmPath + ":organizations) - View all organizations\n")
	b.WriteString("- [Create Task](" + realmPath + ":task/create) - Create your task\n")
	b.WriteString("- [Browse Tasks](" + realmPath + ":tasks) - View all tasks\n\n")

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

	createOrgLink := txlink.Call("CreateOrganization", "name", "", "bio", "", "website", "", "avatar", "")
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

	b.WriteString("Create a new task/bounty for one of your organizations.\n\n")

	b.WriteString("## You must have an organization to create a task/bounty\n\n")

	createTaskLink := txlink.Call("CreateTask", "id", "", "title", "", "description", "", "reward", "")

	b.WriteString("[Create Task](" + createTaskLink + ")\n\n")

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
	}

	b.WriteString("**Created:** Block #" + strconv.FormatInt(task.CreatedAt, 10) + "\n\n")

	b.WriteString("## Description\n\n")
	b.WriteString(task.Description + "\n\n")

	// Admin actions
	caller := std.OriginCaller()
	if caller == org.Admin {
		b.WriteString("## ⚙️ Admin Actions\n\n")
		if task.Status == TaskOpen {
			b.WriteString("- Assign Task (coming soon)\n")
		}
		b.WriteString("- Edit Task (coming soon)\n")
		b.WriteString("- Delete Task (coming soon)\n\n")
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
		b.WriteString("- Edit Organization (coming soon)\n")
	}

	res.Write(b.String())
}

// Public functions that can be called via transactions
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
		CreatedAt:      std.ChainHeight(),
	}

	tasks.Set(strconv.Itoa(taskCounter), task)

	// Add task to organization
	org.Tasks = append(org.Tasks, taskCounter)
	organizations.Set(strconv.Itoa(orgID), org)
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

	// Show truncated description
	description := task.Description
	if len(description) > 100 {
		description = description[:97] + "..."
	}
	b.WriteString("**Description:** " + description + "\n\n")
}

