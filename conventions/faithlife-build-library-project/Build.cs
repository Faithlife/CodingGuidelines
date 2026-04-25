return BuildRunner.Execute(args,
	build => build.AddDotNetTargets(
		new DotNetBuildSettings
		{
			NuGetApiKey = Environment.GetEnvironmentVariable("NUGET_API_KEY"),
			PackageSettings = new DotNetPackageSettings { PushTagOnPublish = x => $"v{x.Version}" },
		}));
