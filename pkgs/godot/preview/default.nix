{
    version = "4.8-dev7";
    hash = "sha256-av3osUZQ7vcpF9dBgvwXvHHiVet+NDt8DzhG1vbwKDA=";
    rev = "c971f93e7e76b0ef919bf6009e7b868bea04db7f";
    default = {
        exportTemplatesHash = "sha256-lcJndVW09mx+7KGkE2hnRwNJfhkHqtP+VldkI8o8jMY=";
    };
    mono = {
        exportTemplatesHash = "sha256-GblVj2Rq3d4eCB+CmPPzFODVOnj9OncP4xEODK+jzsY=";
        nugetDeps = ./deps.json;
    };
}
