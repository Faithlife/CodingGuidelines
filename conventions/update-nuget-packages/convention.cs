#:package NuGet.Configuration@7.3.1
#:package NuGet.Protocol@7.3.1
#:property NuGetAudit=false

using NuGet.Common;
using NuGet.Configuration;
using NuGet.Frameworks;
using NuGet.Protocol;
using NuGet.Protocol.Core.Types;
using NuGet.Versioning;
using System.Diagnostics;
using System.Globalization;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using System.Xml;

try
{
	var app = new UpdateNugetPackagesApp(args);
	await app.RunAsync();
	return 0;
}
catch (Exception exception)
{
	Console.Error.WriteLine(exception.Message);
	return 1;
}

internal sealed class UpdateNugetPackagesApp
{
	public UpdateNugetPackagesApp(string[] args) => m_args = args;

	public async Task RunAsync()
	{
		if (m_args.Length != 1)
			throw new InvalidOperationException("Usage: dotnet convention.cs <convention-input.json>");

		var input = ConventionInput.Read(m_args[0]);
		var repositoryRoot = Git.GetRepositoryRoot(Directory.GetCurrentDirectory());
		var nowUtc = input.NowUtc ?? DateTimeOffset.UtcNow;
		var cutoffUtc = GetPublishCutoffUtc(nowUtc);
		IMetadataSource metadataSource = input.MetadataFilePath is not null ? new FileMetadataSource(input.MetadataFilePath) : new NuGetMetadataSource(repositoryRoot);
		var trackedFiles = Git.GetTrackedFiles(repositoryRoot).Where(IsSupportedPath).Order(StringComparer.Ordinal).ToList();
		var referencesByFile = new Dictionary<string, List<VersionReference>>(StringComparer.Ordinal);

		foreach (var relativePath in trackedFiles)
		{
			var absolutePath = Path.Combine(repositoryRoot, relativePath);
			var content = FileContent.Read(absolutePath);
			var references = Path.GetFileName(relativePath).Equals("dotnet-tools.json", StringComparison.OrdinalIgnoreCase) ?
				ReferenceFinder.FindDotNetToolReferences(relativePath, content.Text) :
				ReferenceFinder.FindXmlReferences(relativePath, content.Text);

			if (references.Count != 0)
				referencesByFile.Add(relativePath, references);
		}

		var replacementsByFile = new Dictionary<string, List<Replacement>>(StringComparer.Ordinal);
		var updatedPackageSummaries = new SortedSet<string>(StringComparer.OrdinalIgnoreCase);
		var heldPackageMessages = new SortedSet<string>(StringComparer.OrdinalIgnoreCase);
		var frameworkResolver = new TargetFrameworkResolver(repositoryRoot, trackedFiles);

		// Returns the eligible versions that support every target framework using the reference, newest first.
		async Task<List<NuGetVersion>> GetAllowedVersionsAsync(VersionReference reference, NuGetVersion currentVersion)
		{
			var rule = input.GetEffectiveRule(reference.PackageId);
			if (rule.VersionPolicy == VersionPolicy.NoUpdate)
				return [];

			var candidates = await metadataSource.GetVersionsAsync(reference.PackageId);
			var eligibleCandidates = VersionResolver.GetEligibleCandidates(currentVersion, candidates, rule, cutoffUtc);
			if (eligibleCandidates.Count == 0 || !TargetFrameworkCompatibility.IsApplicable(reference) || eligibleCandidates.All(x => x.Frameworks is null))
				return eligibleCandidates.Select(x => x.Version).ToList();

			var requirement = frameworkResolver.GetRequirement(reference);
			var currentFrameworks = candidates.FirstOrDefault(x => x.Version == currentVersion && x.Frameworks is not null)?.Frameworks;
			var allowedVersions = new List<NuGetVersion>();
			string? firstIncompatibility = null;

			foreach (var candidate in eligibleCandidates)
			{
				var incompatibility = TargetFrameworkCompatibility.FindIncompatibility(candidate, requirement, currentFrameworks);
				if (incompatibility is null)
					allowedVersions.Add(candidate.Version);
				else if (allowedVersions.Count == 0)
					firstIncompatibility ??= incompatibility;
			}

			if (firstIncompatibility is not null)
			{
				var heldVersion = (allowedVersions.FirstOrDefault() ?? currentVersion).ToNormalizedString();
				heldPackageMessages.Add(string.Create(CultureInfo.InvariantCulture, $"{reference.PackageId} held at {heldVersion}: {eligibleCandidates[0].Version.ToNormalizedString()} does not support {firstIncompatibility}"));
			}

			return allowedVersions;
		}

		foreach (var (relativePath, references) in referencesByFile.OrderBy(x => x.Key, StringComparer.Ordinal))
		{
			// References that share a version property must all move to the same version.
			foreach (var group in references.GroupBy(x => (x.SpanStart, x.SpanLength)).OrderBy(x => x.Key.SpanStart))
			{
				var groupReferences = group.ToList();
				var reference = groupReferences[0];
				if (!NuGetVersion.TryParse(reference.CurrentVersion, out var currentVersion) || currentVersion is null)
				{
					continue;
				}

				var allowedVersionsByReference = new List<List<NuGetVersion>>();
				foreach (var groupReference in groupReferences)
					allowedVersionsByReference.Add(await GetAllowedVersionsAsync(groupReference, currentVersion));

				var selectedVersion = allowedVersionsByReference[0].FirstOrDefault(version => allowedVersionsByReference.All(x => x.Contains(version)));
				if (groupReferences.Count > 1)
				{
					for (var index = 0; index < groupReferences.Count; index++)
					{
						var bestVersion = allowedVersionsByReference[index].FirstOrDefault();
						if (bestVersion is not null && bestVersion != selectedVersion)
						{
							var otherPackageIds = string.Join(", ", groupReferences.Where((_, otherIndex) => otherIndex != index).Select(x => x.PackageId).Distinct(StringComparer.OrdinalIgnoreCase));
							heldPackageMessages.Add(string.Create(CultureInfo.InvariantCulture, $"{groupReferences[index].PackageId} held at {(selectedVersion ?? currentVersion).ToNormalizedString()}: {bestVersion.ToNormalizedString()} is not available for every package that shares its version property ({otherPackageIds})"));
						}
					}
				}

				if (selectedVersion is null)
				{
					continue;
				}

				var selectedVersionText = selectedVersion.ToNormalizedString();
				if (!replacementsByFile.TryGetValue(relativePath, out var fileReplacements))
				{
					fileReplacements = new List<Replacement>();
					replacementsByFile.Add(relativePath, fileReplacements);
				}

				fileReplacements.Add(new Replacement(reference.SpanStart, reference.SpanLength, reference.CurrentVersion, selectedVersionText, reference.Line, reference.PackageId));
				foreach (var groupReference in groupReferences)
					updatedPackageSummaries.Add(string.Create(CultureInfo.InvariantCulture, $"{groupReference.PackageId} {selectedVersionText} (from {groupReference.CurrentVersion})"));
			}
		}

		foreach (var (relativePath, replacements) in replacementsByFile.OrderBy(x => x.Key, StringComparer.Ordinal))
		{
			var absolutePath = Path.Combine(repositoryRoot, relativePath);
			var content = FileContent.Read(absolutePath);
			var updatedText = ReplacementEngine.Apply(content.Text, replacements);

			if (!string.Equals(content.Text, updatedText, StringComparison.Ordinal))
				content.Write(updatedText);
		}

		foreach (var heldPackageMessage in heldPackageMessages)
			Console.WriteLine(heldPackageMessage);

		if (updatedPackageSummaries.Count != 0)
		{
			Console.WriteLine(string.Create(CultureInfo.InvariantCulture, $"{updatedPackageSummaries.Count} packages updated:"));
			foreach (var packageSummary in updatedPackageSummaries)
				Console.WriteLine(string.Create(CultureInfo.InvariantCulture, $"- {packageSummary}"));
		}
	}

	private static bool IsSupportedPath(string relativePath)
	{
		var fileName = Path.GetFileName(relativePath);
		if (fileName.Equals("dotnet-tools.json", StringComparison.OrdinalIgnoreCase))
			return true;

		var extension = Path.GetExtension(relativePath);
		return extension.Equals(".csproj", StringComparison.OrdinalIgnoreCase) ||
			extension.Equals(".props", StringComparison.OrdinalIgnoreCase) ||
			extension.Equals(".targets", StringComparison.OrdinalIgnoreCase);
	}

	private static DateTimeOffset GetPublishCutoffUtc(DateTimeOffset nowUtc)
	{
		var utcDate = nowUtc.UtcDateTime.Date;
		var daysSinceTuesday = ((int) utcDate.DayOfWeek - (int) DayOfWeek.Tuesday + 7) % 7;
		var lastTuesday = daysSinceTuesday == 0 ? utcDate.AddDays(-7) : utcDate.AddDays(-daysSinceTuesday);
		var tuesdayBeforeLastTuesday = lastTuesday.AddDays(-7);
		return new DateTimeOffset(tuesdayBeforeLastTuesday.AddDays(1).AddTicks(-1), TimeSpan.Zero);
	}

	private readonly string[] m_args;
}

internal sealed class ConventionInput
{
	public string? MetadataFilePath { get; }
	public DateTimeOffset? NowUtc { get; }

	public static ConventionInput Read(string inputPath)
	{
		using var document = JsonDocument.Parse(File.ReadAllText(inputPath));
		var settings = document.RootElement.TryGetProperty("settings", out var settingsElement) && settingsElement.ValueKind == JsonValueKind.Object ? settingsElement : default;
		var rules = new List<Rule>();

		if (settings.ValueKind == JsonValueKind.Object && settings.TryGetProperty("rules", out var rulesElement))
		{
			if (rulesElement.ValueKind != JsonValueKind.Array)
				throw new InvalidOperationException("The 'rules' setting must be an array.");

			foreach (var ruleElement in rulesElement.EnumerateArray())
				rules.Add(Rule.Parse(ruleElement));
		}

		string? metadataFilePath = null;
		DateTimeOffset? nowUtc = null;
		var testMode = string.Equals(Environment.GetEnvironmentVariable("UPDATE_NUGET_PACKAGES_TEST_MODE"), "1", StringComparison.Ordinal);

		if (testMode && settings.ValueKind == JsonValueKind.Object)
		{
			if (settings.TryGetProperty("test-package-metadata-file", out var metadataElement) && metadataElement.ValueKind == JsonValueKind.String)
				metadataFilePath = metadataElement.GetString();

			if (settings.TryGetProperty("now-utc", out var nowElement) && nowElement.ValueKind == JsonValueKind.String)
				nowUtc = DateTimeOffset.Parse(nowElement.GetString()!, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal);
		}

		return new ConventionInput(rules, metadataFilePath, nowUtc);
	}

	public EffectiveRule GetEffectiveRule(string packageId)
	{
		var effectiveRule = new EffectiveRule();

		foreach (var rule in m_rules)
		{
			if (!rule.IsMatch(packageId))
				continue;

			if (rule.HasVersion)
			{
				effectiveRule.VersionPolicy = rule.VersionPolicy;
				effectiveRule.ExactVersion = rule.ExactVersion;
				effectiveRule.AllowedVersionRange = rule.AllowedVersionRange;
			}

			if (rule.IncludePrerelease.HasValue)
				effectiveRule.IncludePrerelease = rule.IncludePrerelease.Value;

			if (rule.PrereleaseChannel is not null)
				effectiveRule.PrereleaseChannel = rule.PrereleaseChannel;

			if (rule.PublishCooldownPolicy.HasValue)
				effectiveRule.PublishCooldownPolicy = rule.PublishCooldownPolicy.Value;
		}

		return effectiveRule;
	}

	private ConventionInput(List<Rule> rules, string? metadataFilePath, DateTimeOffset? nowUtc)
	{
		m_rules = rules;
		MetadataFilePath = metadataFilePath;
		NowUtc = nowUtc;
	}

	private readonly List<Rule> m_rules;
}

internal sealed class Rule
{
	public bool HasVersion { get; }
	public VersionPolicy VersionPolicy { get; }
	public NuGetVersion? ExactVersion { get; }
	public VersionRange? AllowedVersionRange { get; }
	public bool? IncludePrerelease { get; }
	public string? PrereleaseChannel { get; }
	public PublishCooldown? PublishCooldownPolicy { get; }

	public static Rule Parse(JsonElement element)
	{
		if (element.ValueKind != JsonValueKind.Object)
			throw new InvalidOperationException("Each rule must be an object.");

		if (!element.TryGetProperty("packages", out var packagesElement))
			throw new InvalidOperationException("Each rule must specify 'packages'.");

		var packages = ReadStringOrArray(packagesElement, "packages");
		var hasVersion = element.TryGetProperty("version", out var versionElement);
		var versionPolicy = VersionPolicy.UpdateMajor;
		NuGetVersion? exactVersion = null;
		VersionRange? allowedVersionRange = null;

		if (hasVersion)
		{
			if (versionElement.ValueKind != JsonValueKind.String)
				throw new InvalidOperationException("Rule 'version' must be a string.");

			var versionText = versionElement.GetString()!;
			switch (versionText)
			{
				case "update-major":
					versionPolicy = VersionPolicy.UpdateMajor;
					break;
				case "update-minor":
					versionPolicy = VersionPolicy.UpdateMinor;
					break;
				case "update-patch":
					versionPolicy = VersionPolicy.UpdatePatch;
					break;
				case "no-update":
					versionPolicy = VersionPolicy.NoUpdate;
					break;
				default:
					if ((versionText.Length != 0 && (versionText[0] == '[' || versionText[0] == '(')) &&
						VersionRange.TryParse(versionText, out allowedVersionRange) &&
						allowedVersionRange is not null)
					{
						versionPolicy = VersionPolicy.Exact;
						break;
					}

					if (!NuGetVersion.TryParse(versionText, out exactVersion) || exactVersion is null)
						throw new InvalidOperationException($"Rule 'version' value '{versionText}' is not a supported policy, exact version, or version range.");

					versionPolicy = VersionPolicy.Exact;
					break;
			}
		}

		bool? includePrerelease = null;
		if (element.TryGetProperty("include-prerelease", out var includePrereleaseElement))
		{
			if (includePrereleaseElement.ValueKind != JsonValueKind.True && includePrereleaseElement.ValueKind != JsonValueKind.False)
				throw new InvalidOperationException("Rule 'include-prerelease' must be a boolean.");

			includePrerelease = includePrereleaseElement.GetBoolean();
		}

		string? prereleaseChannel = null;
		if (element.TryGetProperty("prerelease-channel", out var prereleaseChannelElement))
		{
			if (prereleaseChannelElement.ValueKind != JsonValueKind.String)
				throw new InvalidOperationException("Rule 'prerelease-channel' must be a string.");

			prereleaseChannel = prereleaseChannelElement.GetString();
		}

		PublishCooldown? publishCooldown = null;
		if (element.TryGetProperty("publish-cooldown", out var publishCooldownElement))
		{
			if (publishCooldownElement.ValueKind != JsonValueKind.String)
				throw new InvalidOperationException("Rule 'publish-cooldown' must be a string.");

			publishCooldown = publishCooldownElement.GetString() switch
			{
				"weekly" => PublishCooldown.Weekly,
				"none" => PublishCooldown.None,
				_ => throw new InvalidOperationException("Rule 'publish-cooldown' must be 'weekly' or 'none'.")
			};
		}

		return new Rule(packages, hasVersion, versionPolicy, exactVersion, allowedVersionRange, includePrerelease, prereleaseChannel, publishCooldown);
	}

	public bool IsMatch(string packageId) => m_packagePatterns.Any(pattern => pattern.IsMatch(packageId));

	private static List<string> ReadStringOrArray(JsonElement element, string propertyName)
	{
		if (element.ValueKind == JsonValueKind.String)
			return new List<string> { element.GetString()! };

		if (element.ValueKind == JsonValueKind.Array)
		{
			var values = new List<string>();
			foreach (var item in element.EnumerateArray())
			{
				if (item.ValueKind != JsonValueKind.String)
					throw new InvalidOperationException($"Rule '{propertyName}' values must be strings.");

				values.Add(item.GetString()!);
			}

			return values;
		}

		throw new InvalidOperationException($"Rule '{propertyName}' must be a string or string array.");
	}

	private static Regex CreateWildcardRegex(string pattern)
	{
		var regex = "^" + Regex.Escape(pattern).Replace("\\*", ".*").Replace("\\?", ".") + "$";
		return new Regex(regex, RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);
	}

	private Rule(List<string> packages, bool hasVersion, VersionPolicy versionPolicy, NuGetVersion? exactVersion, VersionRange? allowedVersionRange, bool? includePrerelease, string? prereleaseChannel, PublishCooldown? publishCooldown)
	{
		m_packagePatterns = packages.Select(CreateWildcardRegex).ToList();
		HasVersion = hasVersion;
		VersionPolicy = versionPolicy;
		ExactVersion = exactVersion;
		AllowedVersionRange = allowedVersionRange;
		IncludePrerelease = includePrerelease;
		PrereleaseChannel = prereleaseChannel;
		PublishCooldownPolicy = publishCooldown;
	}

	private readonly List<Regex> m_packagePatterns;
}

internal sealed class EffectiveRule
{
	public VersionPolicy VersionPolicy { get; set; } = VersionPolicy.UpdateMajor;
	public NuGetVersion? ExactVersion { get; set; }
	public VersionRange? AllowedVersionRange { get; set; }
	public bool IncludePrerelease { get; set; }
	public string? PrereleaseChannel { get; set; }
	public PublishCooldown PublishCooldownPolicy { get; set; } = PublishCooldown.Weekly;
}

internal enum PublishCooldown
{
	Weekly,
	None
}

internal enum VersionPolicy
{
	UpdateMajor,
	UpdateMinor,
	UpdatePatch,
	NoUpdate,
	Exact
}

internal sealed record VersionReference(string RelativePath, string PackageId, string CurrentVersion, int SpanStart, int SpanLength, int Line, string Kind);
internal sealed record Replacement(int Start, int Length, string OldText, string NewText, int Line, string PackageId);

// Frameworks are the dependency group target frameworks; null means the package declares none and is treated as compatible.
internal sealed record CandidateVersion(NuGetVersion Version, DateTimeOffset? PublishedUtc, bool Listed, IReadOnlyList<NuGetFramework>? Frameworks = null);

internal interface IMetadataSource
{
	Task<IReadOnlyList<CandidateVersion>> GetVersionsAsync(string packageId);
}

internal sealed class FileMetadataSource : IMetadataSource
{
	public FileMetadataSource(string path)
	{
		m_versions = new Dictionary<string, IReadOnlyList<CandidateVersion>>(StringComparer.OrdinalIgnoreCase);
		using var document = JsonDocument.Parse(File.ReadAllText(path));
		var root = document.RootElement.TryGetProperty("packages", out var packagesElement) ? packagesElement : document.RootElement;

		foreach (var packageProperty in root.EnumerateObject())
		{
			var candidates = new List<CandidateVersion>();
			foreach (var versionElement in packageProperty.Value.EnumerateArray())
			{
				var versionText = versionElement.GetProperty("version").GetString()!;
				if (!NuGetVersion.TryParse(versionText, out var version) || version is null)
					continue;

				DateTimeOffset? publishedUtc = null;
				if (versionElement.TryGetProperty("publishedUtc", out var publishedElement) && publishedElement.ValueKind == JsonValueKind.String)
					publishedUtc = DateTimeOffset.Parse(publishedElement.GetString()!, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal);

				var listed = !versionElement.TryGetProperty("listed", out var listedElement) || listedElement.GetBoolean();

				List<NuGetFramework>? frameworks = null;
				if (versionElement.TryGetProperty("frameworks", out var frameworksElement) && frameworksElement.ValueKind == JsonValueKind.Array)
					frameworks = frameworksElement.EnumerateArray().Select(x => NuGetFramework.Parse(x.GetString()!)).ToList();

				candidates.Add(new CandidateVersion(version, publishedUtc, listed, frameworks is { Count: > 0 } ? frameworks : null));
			}

			m_versions.Add(packageProperty.Name, candidates);
		}
	}

	public Task<IReadOnlyList<CandidateVersion>> GetVersionsAsync(string packageId)
	{
		return Task.FromResult(m_versions.TryGetValue(packageId, out var versions) ? versions : []);
	}

	private readonly Dictionary<string, IReadOnlyList<CandidateVersion>> m_versions;
}

internal sealed class NuGetMetadataSource : IMetadataSource
{
	public NuGetMetadataSource(string repositoryRoot)
	{
		var settings = Settings.LoadDefaultSettings(repositoryRoot);
		var packageSourceProvider = new PackageSourceProvider(settings);
		m_repositories = packageSourceProvider.LoadPackageSources()
			.Where(source => source.IsEnabled)
			.Select(source => new SourceRepository(source, Repository.Provider.GetCoreV3()))
			.ToList();

		if (m_repositories.Count == 0)
			throw new InvalidOperationException("No enabled NuGet package sources were found.");
	}

	public async Task<IReadOnlyList<CandidateVersion>> GetVersionsAsync(string packageId)
	{
		var versions = new List<CandidateVersion>();
		using var cacheContext = new SourceCacheContext();

		foreach (var repository in m_repositories)
		{
			try
			{
				var resource = await repository.GetResourceAsync<PackageMetadataResource>();
				var metadata = await resource.GetMetadataAsync(packageId, includePrerelease: true, includeUnlisted: true, cacheContext, NullLogger.Instance, CancellationToken.None);

				foreach (var item in metadata)
				{
					var publishedUtc = repository.PackageSource.IsHttp ? item.Published : DateTimeOffset.MinValue;
					var frameworks = item.DependencySets.Select(x => x.TargetFramework).ToList();
					versions.Add(new CandidateVersion(
						item.Identity.Version,
						publishedUtc,
						item.IsListed,
						frameworks.Count != 0 ? frameworks : null));
				}
			}
			catch (Exception exception) when (exception is FatalProtocolException or HttpRequestException or TaskCanceledException)
			{
				Console.Error.WriteLine($"Skipping source '{repository.PackageSource.Source}' for package '{packageId}': {exception.Message}");
			}
		}

		return versions;
	}

	private readonly List<SourceRepository> m_repositories;
}

internal static class VersionResolver
{
	public static List<CandidateVersion> GetEligibleCandidates(NuGetVersion currentVersion, IReadOnlyList<CandidateVersion> candidates, EffectiveRule rule, DateTimeOffset cutoffUtc)
	{
		return candidates
			.Where(candidate => candidate.Listed)
			.Where(candidate => rule.PublishCooldownPolicy == PublishCooldown.None || (candidate.PublishedUtc.HasValue && candidate.PublishedUtc.Value <= cutoffUtc))
			.Where(candidate => candidate.Version.CompareTo(currentVersion) > 0)
			.Where(candidate => IsPrereleaseAllowed(candidate.Version, rule))
			.Where(candidate => IsAllowedByPolicy(candidate.Version, currentVersion, rule))
			.GroupBy(candidate => candidate.Version)
			.Select(group => group.FirstOrDefault(candidate => candidate.Frameworks is not null) ?? group.First())
			.OrderByDescending(candidate => candidate.Version)
			.ToList();
	}

	private static bool IsPrereleaseAllowed(NuGetVersion version, EffectiveRule rule)
	{
		if (rule.PrereleaseChannel is not null)
			return version.IsPrerelease && UsesPrereleaseChannel(version, rule.PrereleaseChannel);

		if (!version.IsPrerelease)
			return true;

		if (!rule.IncludePrerelease)
			return false;

		return true;
	}

	private static bool IsAllowedByPolicy(NuGetVersion version, NuGetVersion currentVersion, EffectiveRule rule)
	{
		return rule.VersionPolicy switch
		{
			VersionPolicy.UpdateMajor => true,
			VersionPolicy.UpdateMinor => version.Major == currentVersion.Major,
			VersionPolicy.UpdatePatch => version.Major == currentVersion.Major && version.Minor == currentVersion.Minor,
			VersionPolicy.Exact =>
				(rule.ExactVersion is not null && version.CompareTo(rule.ExactVersion) == 0) ||
				(rule.AllowedVersionRange is not null && rule.AllowedVersionRange.Satisfies(version)),
			VersionPolicy.NoUpdate => false,
			_ => false
		};
	}

	private static bool UsesPrereleaseChannel(NuGetVersion version, string channel)
	{
		return version.Release.Split('.', StringSplitOptions.RemoveEmptyEntries).Any(part => string.Equals(part, channel, StringComparison.OrdinalIgnoreCase));
	}
}

internal sealed record TargetFrameworkRequirement(IReadOnlyList<NuGetFramework> Frameworks, bool HasUnknownProjects);

internal static class TargetFrameworkCompatibility
{
	// MSBuild SDKs and .NET tools are not restored against project target frameworks.
	public static bool IsApplicable(VersionReference reference) => reference.Kind.StartsWith("xml-", StringComparison.Ordinal);

	public static string? FindIncompatibility(CandidateVersion candidate, TargetFrameworkRequirement requirement, IReadOnlyList<NuGetFramework>? currentFrameworks)
	{
		if (candidate.Frameworks is null)
			return null;

		// Only enforce frameworks that the current version's dependency groups support. Restore already works with the
		// current version, so a framework it doesn't list means the groups don't describe compatibility (e.g. build-only packages).
		foreach (var framework in requirement.Frameworks.Where(x => currentFrameworks is null || Supports(currentFrameworks, x)))
		{
			if (!Supports(candidate.Frameworks, framework))
				return framework.GetShortFolderName();
		}

		// When some projects have unknown target frameworks, don't drop a framework that the current version supports.
		if (requirement.HasUnknownProjects && currentFrameworks is not null)
		{
			foreach (var framework in currentFrameworks.Where(IsSpecific))
			{
				if (!Supports(candidate.Frameworks, framework))
					return framework.GetShortFolderName();
			}
		}

		return null;
	}

	private static bool Supports(IReadOnlyList<NuGetFramework> packageFrameworks, NuGetFramework projectFramework) =>
		!IsSpecific(projectFramework) ||
		packageFrameworks.Any(packageFramework => !IsSpecific(packageFramework) || DefaultCompatibilityProvider.Instance.IsCompatible(projectFramework, packageFramework));

	private static bool IsSpecific(NuGetFramework framework) => !framework.IsAny && !framework.IsUnsupported && !framework.IsAgnostic;
}

internal sealed class TargetFrameworkResolver
{
	public TargetFrameworkResolver(string repositoryRoot, IReadOnlyList<string> trackedFiles)
	{
		m_repositoryRoot = repositoryRoot;
		m_projectPaths = trackedFiles.Where(IsProjectPath).ToList();
	}

	public TargetFrameworkRequirement GetRequirement(VersionReference reference)
	{
		var referencePath = reference.RelativePath;
		IEnumerable<string> projects;
		if (IsProjectPath(referencePath))
		{
			projects = [referencePath];
		}
		else
		{
			// A shared MSBuild file applies to the projects below it; a central PackageVersion applies only to projects that use the package.
			var directory = Path.GetDirectoryName(referencePath) ?? "";
			var scopedProjects = m_projectPaths.Where(x => directory.Length == 0 || x.StartsWith(directory + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase)).ToList();
			if (scopedProjects.Count == 0)
				scopedProjects = m_projectPaths;

			projects = IsPackageVersion(reference) ?
				scopedProjects.Where(x => GetPackageIds(x).Contains(reference.PackageId)) :
				scopedProjects;
		}

		var frameworks = new List<NuGetFramework>();
		var hasProjects = false;
		var hasUnknownProjects = false;
		foreach (var project in projects)
		{
			hasProjects = true;
			var projectFrameworks = GetFrameworks(project);
			if (projectFrameworks is null)
				hasUnknownProjects = true;
			else
				frameworks.AddRange(projectFrameworks.Where(x => !frameworks.Contains(x)));
		}

		return new TargetFrameworkRequirement(frameworks, hasUnknownProjects || !hasProjects);
	}

	private IReadOnlyList<NuGetFramework>? GetFrameworks(string projectPath)
	{
		if (!m_frameworksByProject.TryGetValue(projectPath, out var frameworks))
		{
			frameworks = ReadFrameworks(projectPath);
			if (frameworks is null)
				Console.Error.WriteLine($"Could not determine target frameworks for '{projectPath}'; not updating packages to versions that drop a currently supported framework.");

			m_frameworksByProject.Add(projectPath, frameworks);
		}

		return frameworks;
	}

	private List<NuGetFramework>? ReadFrameworks(string projectPath)
	{
		var absolutePath = Path.Combine(m_repositoryRoot, projectPath);
		var projectText = ReadText(absolutePath);
		if (projectText is null)
			return null;

		// Prefer literal values in the project, then in Directory.Build.props files above it.
		var files = new List<string> { projectText };
		files.AddRange(GetAncestorFiles(absolutePath, "Directory.Build.props").Select(ReadText).OfType<string>());

		foreach (var text in files)
		{
			var values = TargetFrameworkRegex.Matches(text).Select(x => x.Groups["value"].Value.Trim()).ToList();
			if (values.Count == 0)
				continue;

			var resolvedValues = values.Select(x => ResolveProperties(x, files)).ToList();
			if (resolvedValues.All(x => x is not null))
				return ParseFrameworks(resolvedValues!);

			break;
		}

		// Fall back to MSBuild evaluation for SDK-style projects whose frameworks aren't literal.
		return SdkProjectRegex.IsMatch(projectText) ? ReadFrameworksWithMSBuild(absolutePath) : null;
	}

	private static string? ResolveProperties(string value, IReadOnlyList<string> files)
	{
		for (var depth = 0; depth < 5 && value.Contains("$(", StringComparison.Ordinal); depth++)
		{
			var unresolved = false;
			value = PropertyReferenceRegex.Replace(value, match =>
			{
				var name = match.Groups["name"].Value;
				foreach (var text in files)
				{
					var definitions = Regex.Matches(text, @"<" + Regex.Escape(name) + @"\b[^>]*>(?<value>[^<]*)</" + Regex.Escape(name) + ">", RegexOptions.CultureInvariant);
					if (definitions.Count == 1)
						return definitions[0].Groups["value"].Value.Trim();
				}

				unresolved = true;
				return match.Value;
			});

			if (unresolved)
				return null;
		}

		return value.Contains("$(", StringComparison.Ordinal) ? null : value;
	}

	private static List<NuGetFramework>? ParseFrameworks(IEnumerable<string> values)
	{
		var frameworks = values
			.SelectMany(x => x.Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
			.Select(x => NuGetFramework.Parse(x))
			.Distinct()
			.ToList();

		return frameworks.Count != 0 && frameworks.All(x => !x.IsUnsupported) ? frameworks : null;
	}

	private static List<NuGetFramework>? ReadFrameworksWithMSBuild(string absolutePath)
	{
		try
		{
			var startInfo = new ProcessStartInfo("dotnet")
			{
				WorkingDirectory = Path.GetDirectoryName(absolutePath)!,
				RedirectStandardOutput = true,
				RedirectStandardError = true,
				UseShellExecute = false,
			};
			foreach (var argument in new[] { "msbuild", absolutePath, "-nologo", "-getProperty:TargetFramework", "-getProperty:TargetFrameworks" })
				startInfo.ArgumentList.Add(argument);

			using var process = Process.Start(startInfo);
			if (process is null)
				return null;

			var outputTask = process.StandardOutput.ReadToEndAsync();
			_ = process.StandardError.ReadToEndAsync();
			if (!process.WaitForExit(TimeSpan.FromMinutes(2)))
			{
				process.Kill(entireProcessTree: true);
				return null;
			}

			if (process.ExitCode != 0)
				return null;

			using var document = JsonDocument.Parse(outputTask.Result);
			var properties = document.RootElement.GetProperty("Properties");
			return ParseFrameworks(new[] { "TargetFramework", "TargetFrameworks" }.Select(x => properties.TryGetProperty(x, out var value) ? value.GetString() ?? "" : ""));
		}
		catch (Exception exception) when (exception is InvalidOperationException or JsonException or System.ComponentModel.Win32Exception or KeyNotFoundException)
		{
			return null;
		}
	}

	private HashSet<string> GetPackageIds(string projectPath)
	{
		if (!m_packageIdsByProject.TryGetValue(projectPath, out var packageIds))
		{
			var absolutePath = Path.Combine(m_repositoryRoot, projectPath);
			var files = new List<string> { absolutePath };
			files.AddRange(GetAncestorFiles(absolutePath, "Directory.Build.props"));
			files.AddRange(GetAncestorFiles(absolutePath, "Directory.Build.targets"));

			packageIds = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
			foreach (var text in files.Select(ReadText).OfType<string>())
			{
				foreach (Match match in PackageReferenceRegex.Matches(text))
					packageIds.Add(match.Groups["id"].Value.Trim());
			}

			m_packageIdsByProject.Add(projectPath, packageIds);
		}

		return packageIds;
	}

	private IEnumerable<string> GetAncestorFiles(string absoluteProjectPath, string fileName)
	{
		var root = Path.GetFullPath(m_repositoryRoot).TrimEnd(Path.DirectorySeparatorChar);
		var directory = Path.GetDirectoryName(Path.GetFullPath(absoluteProjectPath));
		while (directory is not null && directory.Length >= root.Length)
		{
			var path = Path.Combine(directory, fileName);
			if (File.Exists(path))
				yield return path;

			directory = Path.GetDirectoryName(directory);
		}
	}

	private bool IsPackageVersion(VersionReference reference)
	{
		var text = ReadText(Path.Combine(m_repositoryRoot, reference.RelativePath));
		if (text is null || reference.SpanStart > text.Length)
			return false;

		// Find the nearest package element that starts before the version text.
		var before = text[..reference.SpanStart];
		var packageVersionStart = before.LastIndexOf("<PackageVersion", StringComparison.Ordinal);
		var otherStart = Math.Max(before.LastIndexOf("<PackageReference", StringComparison.Ordinal), before.LastIndexOf("<GlobalPackageReference", StringComparison.Ordinal));
		return packageVersionStart > otherStart;
	}

	private static string? ReadText(string path) => File.Exists(path) ? FileContent.Read(path).Text : null;

	private static bool IsProjectPath(string path) =>
		Path.GetExtension(path) is var extension &&
		(extension.Equals(".csproj", StringComparison.OrdinalIgnoreCase) || extension.Equals(".fsproj", StringComparison.OrdinalIgnoreCase) || extension.Equals(".vbproj", StringComparison.OrdinalIgnoreCase));

	private static Regex TargetFrameworkRegex { get; } = new(@"<(?<name>TargetFrameworks?)\b[^>]*>(?<value>[^<]*)</\k<name>>", RegexOptions.CultureInvariant);
	private static Regex PropertyReferenceRegex { get; } = new(@"\$\((?<name>[A-Za-z_][A-Za-z0-9_.-]*)\)", RegexOptions.CultureInvariant);
	private static Regex PackageReferenceRegex { get; } = new(@"<PackageReference\b[^>]*?\b(?:Include|Update)\s*=\s*([""'])(?<id>[^""']+)\1", RegexOptions.CultureInvariant);
	private static Regex SdkProjectRegex { get; } = new(@"<(?:Project|Import)\b[^>]*\bSdk\s*=|<Sdk\b", RegexOptions.CultureInvariant);

	private readonly string m_repositoryRoot;
	private readonly List<string> m_projectPaths;
	private readonly Dictionary<string, IReadOnlyList<NuGetFramework>?> m_frameworksByProject = new(StringComparer.Ordinal);
	private readonly Dictionary<string, HashSet<string>> m_packageIdsByProject = new(StringComparer.Ordinal);
}

internal static class ReferenceFinder
{
	public static List<VersionReference> FindXmlReferences(string relativePath, string text)
	{
		ValidateXml(relativePath, text);
		var references = new List<VersionReference>();
		var properties = FindProperties(text);

		foreach (Match match in PackageTagRegex.Matches(text))
		{
			var tag = match.Value;
			if (!TryFindAttribute(tag, match.Index, "Include|Update", out var packageAttribute) ||
				!TryFindAttribute(tag, match.Index, "Version|VersionOverride", out var versionAttribute))
				continue;

			AddReference(relativePath, text, references, properties, packageAttribute.Value, versionAttribute.Value, versionAttribute.ValueStart, versionAttribute.ValueLength, "xml-attribute");
		}

		foreach (Match match in PackageElementRegex.Matches(text))
		{
			var tagStart = text.IndexOf('>', match.Index) + 1;
			if (tagStart <= 0)
				continue;

			var openingTag = text.Substring(match.Index, tagStart - match.Index);
			if (!TryFindAttribute(openingTag, match.Index, "Include|Update", out var packageAttribute) || TryFindAttribute(openingTag, match.Index, "Version|VersionOverride", out _))
				continue;

			var body = match.Groups["body"];
			var childMatch = Regex.Match(body.Value, @"<(?<name>Version|VersionOverride)\b[^>]*>(?<value>[^<]+)</\k<name>>", RegexOptions.CultureInvariant | RegexOptions.Singleline);
			if (!childMatch.Success)
				continue;

			var valueGroup = childMatch.Groups["value"];
			AddReference(relativePath, text, references, properties, packageAttribute.Value, valueGroup.Value, body.Index + valueGroup.Index, valueGroup.Length, "xml-element");
		}

		foreach (Match match in ProjectTagRegex.Matches(text))
		{
			if (!TryFindAttribute(match.Value, match.Index, "Sdk", out var sdkAttribute))
				continue;

			foreach (var sdkReference in ParseProjectSdkAttribute(sdkAttribute))
				AddReference(relativePath, text, references, properties, sdkReference.Id, sdkReference.Version, sdkReference.VersionStart, sdkReference.Version.Length, "project-sdk");
		}

		foreach (Match match in ImportTagRegex.Matches(text))
		{
			if (TryFindAttribute(match.Value, match.Index, "Sdk", out var sdkAttribute) && TryFindAttribute(match.Value, match.Index, "Version", out var versionAttribute))
				AddReference(relativePath, text, references, properties, sdkAttribute.Value, versionAttribute.Value, versionAttribute.ValueStart, versionAttribute.ValueLength, "import-sdk");
		}

		foreach (Match match in SdkTagRegex.Matches(text))
		{
			if (TryFindAttribute(match.Value, match.Index, "Name", out var nameAttribute) && TryFindAttribute(match.Value, match.Index, "Version", out var versionAttribute))
				AddReference(relativePath, text, references, properties, nameAttribute.Value, versionAttribute.Value, versionAttribute.ValueStart, versionAttribute.ValueLength, "sdk-element");
		}

		return references;
	}

	public static List<VersionReference> FindDotNetToolReferences(string relativePath, string text)
	{
		using var document = JsonDocument.Parse(text);
		var references = new List<VersionReference>();

		if (!document.RootElement.TryGetProperty("tools", out var toolsElement) || toolsElement.ValueKind != JsonValueKind.Object)
			return references;

		if (!TryFindJsonObjectSpan(text, "tools", out var toolsStart, out var toolsLength))
			return references;

		var toolsText = text.Substring(toolsStart, toolsLength);
		var toolRegex = new Regex(@"""(?<id>[^""\\]+)""\s*:\s*\{(?<body>.*?)\}", RegexOptions.CultureInvariant | RegexOptions.Singleline);
		foreach (Match match in toolRegex.Matches(toolsText))
		{
			var packageId = match.Groups["id"].Value;
			if (!toolsElement.TryGetProperty(packageId, out var toolElement) || toolElement.ValueKind != JsonValueKind.Object)
				continue;

			if (!toolElement.TryGetProperty("version", out var versionElement) || versionElement.ValueKind != JsonValueKind.String)
				continue;

			var body = match.Groups["body"];
			var versionMatch = Regex.Match(body.Value, @"""version""\s*:\s*""(?<value>[^""\\]*)""", RegexOptions.CultureInvariant | RegexOptions.Singleline);
			if (!versionMatch.Success)
				continue;

			var valueGroup = versionMatch.Groups["value"];
			var valueStart = toolsStart + body.Index + valueGroup.Index;
			var value = valueGroup.Value;

			if (IsSupportedLiteralVersion(value))
				references.Add(new VersionReference(relativePath, packageId, value, valueStart, value.Length, GetLineNumber(text, valueStart), "dotnet-tool"));
		}

		return references;
	}

	private static Dictionary<string, List<PropertyDefinition>> FindProperties(string text)
	{
		var properties = new Dictionary<string, List<PropertyDefinition>>(StringComparer.Ordinal);
		foreach (Match match in PropertyRegex.Matches(text))
		{
			var attrs = match.Groups["attrs"].Value;
			if (attrs.Contains("Condition", StringComparison.OrdinalIgnoreCase))
				continue;

			var valueGroup = match.Groups["value"];
			var value = valueGroup.Value.Trim();
			if (!IsSupportedLiteralVersion(value))
				continue;

			var definition = new PropertyDefinition(match.Groups["name"].Value, value, valueGroup.Index, valueGroup.Length);
			if (!properties.TryGetValue(definition.Name, out var definitions))
			{
				definitions = new List<PropertyDefinition>();
				properties.Add(definition.Name, definitions);
			}

			definitions.Add(definition);
		}

		return properties;
	}

	private static void AddReference(string relativePath, string text, List<VersionReference> references, Dictionary<string, List<PropertyDefinition>> properties, string packageId, string versionText, int versionStart, int versionLength, string kind)
	{
		var propertyExpressionMatch = PropertyExpressionRegex.Match(versionText.Trim());
		if (propertyExpressionMatch.Success)
		{
			var propertyName = propertyExpressionMatch.Groups["name"].Value;
			if (!properties.TryGetValue(propertyName, out var definitions) || definitions.Count != 1)
				return;

			var definition = definitions[0];
			references.Add(new VersionReference(relativePath, packageId, definition.Value, definition.ValueStart, definition.ValueLength, GetLineNumber(text, versionStart), kind + "-property"));
			return;
		}

		if (!IsSupportedLiteralVersion(versionText))
			return;

		references.Add(new VersionReference(relativePath, packageId, versionText, versionStart, versionLength, GetLineNumber(text, versionStart), kind));
	}

	private static IEnumerable<ProjectSdkReference> ParseProjectSdkAttribute(AttributeValue sdkAttribute)
	{
		var value = sdkAttribute.Value;
		var segmentStart = 0;
		foreach (var segment in value.Split(';'))
		{
			var slashIndex = segment.LastIndexOf('/');
			if (slashIndex > 0 && slashIndex < segment.Length - 1)
			{
				var id = segment.Substring(0, slashIndex);
				var version = segment.Substring(slashIndex + 1);
				yield return new ProjectSdkReference(id, version, sdkAttribute.ValueStart + segmentStart + slashIndex + 1);
			}

			segmentStart += segment.Length + 1;
		}
	}

	private static bool TryFindAttribute(string tag, int tagStart, string namePattern, out AttributeValue attributeValue)
	{
		attributeValue = default;
		var match = Regex.Match(tag, @"\b(?:" + namePattern + @")\s*=\s*(['""])(?<value>.*?)\1", RegexOptions.CultureInvariant | RegexOptions.Singleline);
		if (!match.Success)
			return false;

		var valueGroup = match.Groups["value"];
		attributeValue = new AttributeValue(valueGroup.Value, tagStart + valueGroup.Index, valueGroup.Length);
		return true;
	}

	private static bool TryFindJsonObjectSpan(string text, string propertyName, out int objectStart, out int objectLength)
	{
		objectStart = 0;
		objectLength = 0;
		var match = Regex.Match(text, @"""" + Regex.Escape(propertyName) + @"""\s*:\s*\{", RegexOptions.CultureInvariant);
		if (!match.Success)
			return false;

		objectStart = match.Index + match.Value.LastIndexOf('{');
		var depth = 0;
		var inString = false;
		var escaped = false;

		for (var index = objectStart; index < text.Length; index++)
		{
			var ch = text[index];
			if (inString)
			{
				if (escaped)
				{
					escaped = false;
				}
				else if (ch == '\\')
				{
					escaped = true;
				}
				else if (ch == '"')
				{
					inString = false;
				}

				continue;
			}

			if (ch == '"')
			{
				inString = true;
			}
			else if (ch == '{')
			{
				depth++;
			}
			else if (ch == '}')
			{
				depth--;
				if (depth == 0)
				{
					objectLength = index - objectStart + 1;
					return true;
				}
			}
		}

		return false;
	}

	private static bool IsSupportedLiteralVersion(string value)
	{
		if (string.IsNullOrWhiteSpace(value))
			return false;

		return !value.Contains('*') &&
			!value.Contains('[') &&
			!value.Contains(']') &&
			!value.Contains('(') &&
			!value.Contains(')') &&
			!value.Contains(',') &&
			!value.Contains("$(", StringComparison.Ordinal) &&
			!value.Contains("@(", StringComparison.Ordinal) &&
			!value.Contains("%(", StringComparison.Ordinal);
	}

	private static int GetLineNumber(string text, int offset)
	{
		var line = 1;
		for (var index = 0; index < offset && index < text.Length; index++)
		{
			if (text[index] == '\n')
				line++;
		}

		return line;
	}

	private static void ValidateXml(string relativePath, string text)
	{
		try
		{
			using var reader = XmlReader.Create(new StringReader(text), new XmlReaderSettings { DtdProcessing = DtdProcessing.Ignore, XmlResolver = null });
			while (reader.Read()) { }
		}
		catch (XmlException exception)
		{
			throw new InvalidOperationException($"Failed to parse XML file '{relativePath}': {exception.Message}", exception);
		}
	}

	private static Regex PropertyRegex { get; } = new(@"<(?<name>[A-Za-z_][A-Za-z0-9_.-]*)\b(?<attrs>[^>]*)>(?<value>[^<]+)</\k<name>>", RegexOptions.CultureInvariant | RegexOptions.Singleline);
	private static Regex PackageTagRegex { get; } = new(@"<(?<element>PackageReference|PackageVersion|GlobalPackageReference)\b(?<attrs>[^<>]*?)(?<self>/?)>", RegexOptions.CultureInvariant | RegexOptions.Singleline);
	private static Regex PackageElementRegex { get; } = new(@"<(?<element>PackageReference|PackageVersion|GlobalPackageReference)\b(?<attrs>[^>]*)>(?<body>.*?)</\k<element>>", RegexOptions.CultureInvariant | RegexOptions.Singleline);
	private static Regex ProjectTagRegex { get; } = new(@"<Project\b(?<attrs>[^<>]*?)>", RegexOptions.CultureInvariant | RegexOptions.Singleline);
	private static Regex ImportTagRegex { get; } = new(@"<Import\b(?<attrs>[^<>]*?)(?<self>/?)>", RegexOptions.CultureInvariant | RegexOptions.Singleline);
	private static Regex SdkTagRegex { get; } = new(@"<Sdk\b(?<attrs>[^<>]*?)(?<self>/?)>", RegexOptions.CultureInvariant | RegexOptions.Singleline);
	private static Regex PropertyExpressionRegex { get; } = new(@"^\$\((?<name>[A-Za-z_][A-Za-z0-9_.-]*)\)$", RegexOptions.CultureInvariant);

	private readonly record struct AttributeValue(string Value, int ValueStart, int ValueLength);
	private readonly record struct PropertyDefinition(string Name, string Value, int ValueStart, int ValueLength);
	private readonly record struct ProjectSdkReference(string Id, string Version, int VersionStart);
}

internal static class ReplacementEngine
{
	public static string Apply(string text, List<Replacement> replacements)
	{
		var orderedReplacements = replacements.OrderBy(replacement => replacement.Start).ToList();
		var uniqueReplacements = new List<Replacement>();

		foreach (var replacement in orderedReplacements)
		{
			var existing = uniqueReplacements.FirstOrDefault(item => item.Start == replacement.Start && item.Length == replacement.Length);
			if (existing is not null)
			{
				if (!string.Equals(existing.NewText, replacement.NewText, StringComparison.Ordinal))
					throw new InvalidOperationException($"Conflicting replacements for package '{replacement.PackageId}' on line {replacement.Line}.");

				continue;
			}

			uniqueReplacements.Add(replacement);
		}

		for (var index = 1; index < uniqueReplacements.Count; index++)
		{
			var previous = uniqueReplacements[index - 1];
			var current = uniqueReplacements[index];
			if (previous.Start + previous.Length > current.Start)
				throw new InvalidOperationException($"Overlapping replacements near line {current.Line}.");
		}

		var builder = new StringBuilder(text);
		foreach (var replacement in uniqueReplacements.OrderByDescending(replacement => replacement.Start))
		{
			var currentText = text.Substring(replacement.Start, replacement.Length);
			if (!string.Equals(currentText, replacement.OldText, StringComparison.Ordinal))
				throw new InvalidOperationException($"Expected '{replacement.OldText}' at replacement span for package '{replacement.PackageId}' on line {replacement.Line}.");

			builder.Remove(replacement.Start, replacement.Length);
			builder.Insert(replacement.Start, replacement.NewText);
		}

		return builder.ToString();
	}
}

internal sealed class FileContent
{
	public string Path { get; }
	public string Text { get; }

	public static FileContent Read(string path)
	{
		var bytes = File.ReadAllBytes(path);
		var hasUtf8Bom = bytes.Length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF;
		var encoding = new UTF8Encoding(hasUtf8Bom);
		var text = encoding.GetString(bytes);
		if (hasUtf8Bom && text.Length != 0 && text[0] == '\uFEFF')
			text = text[1..];

		return new FileContent(path, text, encoding);
	}

	public void Write(string text) => File.WriteAllText(Path, text, Encoding);

	private Encoding Encoding { get; }

	private FileContent(string path, string text, Encoding encoding)
	{
		Path = path;
		Text = text;
		Encoding = encoding;
	}
}

internal static class Git
{
	public static string GetRepositoryRoot(string workingDirectory)
	{
		var result = RunGit(workingDirectory, "rev-parse", "--show-toplevel");
		if (result.ExitCode != 0)
			throw new InvalidOperationException("The update-nuget-packages convention must run inside a git worktree.");

		return result.Output.Trim().Replace('/', Path.DirectorySeparatorChar);
	}

	public static List<string> GetTrackedFiles(string repositoryRoot)
	{
		var result = RunGit(repositoryRoot, "ls-files", "-z");
		if (result.ExitCode != 0)
			throw new InvalidOperationException("Failed to list git-tracked files.");

		return result.Output.Split('\0', StringSplitOptions.RemoveEmptyEntries).Select(path => path.Replace('/', Path.DirectorySeparatorChar)).ToList();
	}

	private static GitResult RunGit(string workingDirectory, params string[] arguments)
	{
		var startInfo = new ProcessStartInfo("git")
		{
			WorkingDirectory = workingDirectory,
			RedirectStandardOutput = true,
			RedirectStandardError = true,
			UseShellExecute = false
		};

		foreach (var argument in arguments)
			startInfo.ArgumentList.Add(argument);

		using var process = Process.Start(startInfo) ?? throw new InvalidOperationException("Failed to start git.");
		var output = process.StandardOutput.ReadToEnd();
		var error = process.StandardError.ReadToEnd();
		process.WaitForExit();
		return new GitResult(process.ExitCode, output, error);
	}

	private sealed record GitResult(int ExitCode, string Output, string Error);
}
