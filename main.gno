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
	orgCounter    int      // organization counter
)

type Organization struct {
	ID        int
	Name      string
	Avatar    string
	Domain    string
	Bio       string
	Website   string
	Admin     std.Address
	Tasks     []int // task IDs (for later)
	CreatedAt int64
}

func init() {
	router.HandleFunc("", homeHandler)
	router.HandleFunc("profile/create", profileCreateHandler)
	router.HandleFunc("organization/create", organizationCreateHandler)
	router.HandleFunc("organization/{id}", organizationHandler)
	router.HandleFunc("organizations", organizationsHandler)
}

func Render(path string) string {
	return router.Render(path)
}

func homeHandler(res *mux.ResponseWriter, req *mux.Request) {
	var b strings.Builder
	b.WriteString("# 🎯 Kontribz - Bounty Manager\n\n")

	b.WriteString("## 📊 Platform Statistics\n\n")
	orgCount := organizations.Size()
	b.WriteString("- **Organizations:** " + strconv.Itoa(orgCount) + "\n")
	b.WriteString("- **Tasks:** 0\n")
	b.WriteString("- **Applications:** 0\n\n")

	b.WriteString("## 🚀 Quick Actions\n\n")
	b.WriteString("- [Create Your Profile](" + realmPath + ":profile/create) - Start by creating your user profile\n")
	b.WriteString("- [Create Organization](" + realmPath + ":organization/create) - Create your organization\n")
	b.WriteString("- [Browse Organizations](" + realmPath + ":organizations) - View all organizations\n\n")

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

	// Tasks (for later)
	b.WriteString("\n## 📋 Tasks (" + strconv.Itoa(len(org.Tasks)) + ")\n\n")

	if len(org.Tasks) == 0 {
		b.WriteString("No tasks yet.\n\n")
	} else {
		b.WriteString("*Task management coming soon...*\n\n")
	}

	caller := std.OriginCaller()
	if caller == org.Admin {
		b.WriteString("## ⚙️ Admin Actions\n\n")
		b.WriteString("- Create New Task (coming soon)\n")
		b.WriteString("- Edit Organization (coming soon)\n")
	}

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

// Helper function
func getOrganization(orgID int) *Organization {
	orgI, ok := organizations.Get(strconv.Itoa(orgID))
	if !ok {
		return nil
	}
	return orgI.(*Organization)
}

