#!/usr/bin/env ruby

$: << File.dirname(__FILE__)

require 'defbuild/projectwriterbase'

module DefBuild
	class EclipseProjectWriter < ProjectFileWriterBase
		def write
			if RUBY_PLATFORM =~ /win32/
				defbuild_command = ["c:/projekte/tools/binary/ruby/1.9.0/bin/ruby.exe", Pathname.new(__FILE__).dirname + 'defbuild.rb']
			else
				defbuild_command = ['dbuild', '']
			end
			
			external_project_paths = []
			@projects.each do |project|
				project.modules.each do |mod|
					external_paths = []
					if Helpers::make_relative2(mod.path, @project.path) =~ /^\.\./
						external_paths << mod.path
					end
					external_project_paths.concat(external_paths.uniq.select do |path|
						project.files.any? {|f| Helpers::make_relative2(f.path, path) !~ /^\.\./ }
					end)
				end
			end
			external_project_paths = external_project_paths.uniq
					
			open_file(@project.path + '.project') do |file|
				file.puts '<?xml version="1.0" encoding="UTF-8"?>'
				file.puts '<projectDescription>'
				file.printf "\t<name>%s</name>\n", @project.name
				file.puts "\t<buildSpec>"
				file.puts "\t\t<buildCommand>"
				file.puts "\t\t\t<name>org.eclipse.cdt.managedbuilder.core.genmakebuilder</name>"
				file.puts "\t\t\t<triggers>clean,full,incremental,</triggers>"
				file.puts "\t\t</buildCommand>"
				file.puts "\t\</buildSpec>"
				file.puts "\t<natures>"
				file.puts "\t\t<nature>org.eclipse.cdt.core.ccnature</nature>"
				file.puts "\t\t<nature>org.eclipse.cdt.managedbuilder.core.managedBuildNature</nature>"
				file.puts "\t\t<nature>org.eclipse.cdt.core.cnature</nature>"
				file.puts "\t</natures>"
				unless external_project_paths.empty?
					file.puts "\t<linkedResources>"
					external_project_paths.each do |path|
						file.puts "\t\t<link>"
						file.printf "\t\t\t<name>%s</name>\n", path.basename
						file.puts "\t\t\t<type>2</type>"
						file.printf "\t\t\t<location>%s</location>\n", path
						file.puts "\t\t</link>"
					end
					file.puts "\t</linkedResources>"
				end
				file.puts "</projectDescription>"
			end
			
			open_file(@project.path + '.cproject') do |file|
				file.puts '<?xml version="1.0" encoding="UTF-8" standalone="no"?>'
				file.puts '<?fileVersion 4.0.0?>'
				file.puts '<cproject>'
				file.puts "\t<storageModule moduleId=\"org.eclipse.cdt.core.settings\">"
				@builds.each do |build|
					cleaned_build = build.gsub(/\//, '_')
					id = '0.' + rand(9999999).to_s
					
					file.printf "\t\t<cconfiguration id=\"%s\">\n", id
					file.printf "\t\t\t<storageModule buildSystemId=\"org.eclipse.cdt.managedbuilder.core.configurationDataProvider\" id=\"%s\" moduleId=\"org.eclipse.cdt.core.settings\" name=\"%s\">\n", id, cleaned_build
					file.printf "\t\t\t\t<extension>\n"
					%w(VCErrorParser MakeErrorParser GCCErrorParser GASErrorParser GLDErrorParser).each do |parser|
						file.printf "\t\t\t\t\t<extension id=\"id.eclipse.cdt.core.%s\" point=\"org.eclipse.cdt.core.ErrorParser\"/>\n", parser
					end
					file.printf "\t\t\t\t</extension>\n"
					file.printf "\t\t\t</storageModule>\n"
					file.printf "\t\t\t<storageModule moduleId=\"cdtBuildSystem\" version=\"4.0.0\">\n"
					file.printf "\t\t\t\t<configuration artifactName=\"%s\" buildProperties=\"\" description=\"\" id=\"%s\" name=\"%s\" parent=\"org.eclipse.cdt.build.core.prefbase.cfg\">\n",
						@project.name, id, cleaned_build
					file.printf "\t\t\t\t\t<folderInfo id=\"%s.\" name=\"/\" resourcePath=\"\">\n", id
					file.printf "\t\t\t\t\t\t<toolChain id=\"org.eclipse.cdt.build.core.prefbase.toolchain.1515086713\" name=\"No ToolChain\" resourceTypeBasedDiscovery=\"false\" superClass=\"org.eclipse.cdt.build.core.prefbase.toolchain\">\n"
					file.printf "\t\t\t\t\t\t\t<targetPlatform id=\"org.eclipse.cdt.build.core.prefbase.toolchain.1515086713.747793681\" name=\"\"/>\n"
					file.printf "\t\t\t\t\t\t\t<builder arguments=\"%s -b %s %s\" ", defbuild_command[1], build, Helpers.make_relative(find_project(build).filename)
					file.printf "autoBuildTarget=\"\" buildPath=\"${ProjDirPath}\" "
					file.printf "cleanBuildTarget=\"--clean\" command=\"%s\" ", defbuild_command[0]
					file.printf "enableAutoBuild=\"false\" enableCleanBuild=\"true\" enableIncrementalBuild=\"true\" "
					file.printf "id=\"org.eclipse.cdt.build.core.settings.default.builder.1820907424\" "
					file.printf "incrementalBuildTarget=\"\" keepEnvironmentInBuildFile=\"false\" managedBuildOn=\"false\" name=\"Gnu Make Builder\" "
					file.printf "parallelizationNumber=\"1\" superClass=\"org.eclipse.cdt.build.core.settings.default.builder\"/>\n"
					[['GNU C++', 'g++', ['cxxSource', 'cxxHeader']]].each do |lang_name, lang_id, cont_types|
						file.printf "\t\t\t\t\t\t\t<tool id=\"org.eclipse.cdt.build.core.settings.holder.695930416\" name=\"%s\" superClass=\"org.eclipse.cdt.build.core.settings.holder\">\n", lang_name
						file.printf "\t\t\t\t\t\t\t\t<option id=\"org.eclipse.cdt.build.core.settings.holder.incpaths.2120298510\" name=\"Include Paths\" superClass=\"org.eclipse.cdt.build.core.settings.holder.incpaths\" valueType=\"includePath\">\n"
						get_attribute(:cpp_include_dir, build).each do |include_dir|
							file.printf "\t\t\t\t\t\t\t\t\t<listOptionValue builtIn=\"false\" value=\"${ProjDirPath}/%s\"/>\n", Helpers.make_relative(include_dir)
						end
						file.printf "\t\t\t\t\t\t\t\t</option>\n"
						file.printf "\t\t\t\t\t\t\t\t<inputType id=\"org.eclipse.cdt.build.core.settings.holder.inType.1009607540\" "
						file.printf "languageId=\"org.eclipse.cdt.core.%s\" languageName=\"%s\" ", lang_id, lang_name
						file.printf "sourceContentType=\"%s\" superClass=\"org.eclipse.cdt.build.core.settings.holder.inType\"/>\n", cont_types.map {|t| 'org.eclipse.cdt.code.' + t}.join(',')
						file.printf "\t\t\t\t\t\t\t</tool>\n"
					end
					file.printf "\t\t\t\t\t\t</toolChain>\n"
					file.printf "\t\t\t\t\t</folderInfo>\n"
					file.printf "\t\t\t\t</configuration>\n"
					file.printf "\t\t\t</storageModule>\n"
					file.printf "\t\t</cconfiguration>\n"
				end
				file.printf "\t</storageModule>\n"
				file.puts '</cproject>'
			end
		end
	end
end

filename = ARGV.shift
writer = DefBuild::EclipseProjectWriter.new(filename, ARGV)
writer.write
