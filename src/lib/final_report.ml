
open Nonstd
module String = Sosa.Native_string
let (//) = Filename.concat

(** Makes the below equivalent.

{[let x = canonicalize "/dsde/deds///desd//de/des/"
let y = canonicalize "./dsde/deds///desd//de/des/"
let z = canonicalize "../../dsde/deds///desd//de/des/"
]} *)
let canonicalize path =
  let rec build acc dir =
    match Filename.dirname dir with
    | d when d = dir -> acc
    | p -> build (Filename.basename dir :: acc) p
  in
  let parts = build [] path in
  String.concat ~sep:"/"
    (if Filename.is_relative path
     then  parts
     else "" :: parts)


(** Here a few useful utility functions to make constructing the
   report data structures easier **)

module Report_utils (V: sig val vc: int end) = struct
  let var_count = V.vc

  (* Helps when the tool is optional and passes a single result
     down to the report *)
  let opt n =
    Option.value_map ~default:[] ~f:(fun o -> [n, o ~var_count])

  (* Helps when tools provide named result tuples where the names
     are passed down to report as well. Allows modifying the name
     when needed via the `namefun` parameter *)
  let named_map ?(namefun=(fun n -> n)) =
    List.map ~f:(fun (n, v) -> namefun n, v ~var_count)

  (* Helps when the tool is optional but produced multiple named
     results to be included in the report *)
  let opt_named_map =
    Option.value_map ~default:[] ~f:named_map
end

module type Semantics = sig

  type 'a repr
  val report :
    ?igv_url_server_prefix: string ->
    vcfs:(string * [ `Saved of [ `Vcf ] ] repr) list ->
    fastqcs:(string * [ `Saved of [ `Fastqc ] ] repr) list ->
    normal_bam: [ `Saved of [ `Bam ] ] repr ->
    normal_bam_flagstat: [ `Saved of [ `Flagstat ] ] repr ->
    tumor_bam: [ `Saved of [ `Bam ] ] repr ->
    tumor_bam_flagstat: [ `Saved of [ `Flagstat ] ] repr ->
    ?optitype_normal: [ `Saved of [ `Optitype_result ] ] repr ->
    ?optitype_tumor: [ `Saved of [ `Optitype_result ] ] repr ->
    ?optitype_rna: [ `Saved of [ `Optitype_result ] ] repr ->
    ?rna_bam: [ `Saved of [ `Bam ] ] repr ->
    ?vaxrank: [ `Saved of [ `Vaxrank ] ] repr ->
    ?rna_bam_flagstat: [ `Saved of [ `Flagstat ] ] repr ->
    ?topiary: [ `Saved of [ `Topiary ] ] repr ->
    ?isovar : [ `Saved of [ `Isovar ] ] repr ->
    ?seq2hla: [ `Saved of [ `Seq2hla_result ] ] repr ->
    ?stringtie: [ `Saved of [ `Gtf ] ] repr ->
    ?bedfile: string ->
    ?kallisto:(string * [ `Saved of [ `Kallisto_result ] ] repr) list ->
    metadata: (string * string) list ->
    string ->
    unit repr
end


module To_json = struct
  (* type 'a repr = 'a Biokepi.EDSL.Compile.To_json.repr *)

  let report
      ?igv_url_server_prefix
      ~vcfs
      ~fastqcs
      ~normal_bam
      ~normal_bam_flagstat
      ~tumor_bam
      ~tumor_bam_flagstat
      ?optitype_normal
      ?optitype_tumor
      ?optitype_rna
      ?rna_bam
      ?vaxrank
      ?rna_bam_flagstat
      ?topiary
      ?isovar
      ?seq2hla
      ?stringtie
      ?bedfile
      ?kallisto
      ~metadata
      run_name =
   fun ~var_count ->
      let args =
        let module Rutils = Report_utils(struct let vc = var_count end) in
        let open Rutils in
        [
          "run-name", `String run_name;
          "metadata", `Assoc (List.map metadata ~f:(fun (k, v) -> k, `String v));
        ]
        @ named_map vcfs
        @ named_map ~namefun:(fun n -> sprintf "%s-fastqc" n) fastqcs
        @ [
          "normal-bam", normal_bam ~var_count;
          "tumor-bam", tumor_bam ~var_count;
          "normal-bam-flagstat", normal_bam_flagstat ~var_count;
          "tumor-bam-flagstat", tumor_bam_flagstat ~var_count;
        ]
        @ opt "optitype-normal" optitype_normal
        @ opt "optitype-tumor" optitype_tumor
        @ opt "optitype-rna" optitype_rna
        @ opt "rna-bam" rna_bam
        @ opt "rna-bam-flagstat" rna_bam_flagstat
        @ opt "vaxrank" vaxrank
        @ opt "topiary" topiary
        @ opt "isovar" isovar
        @ opt "seq2hla" seq2hla
        @ opt "stringtie" stringtie
        @ opt_named_map kallisto
        @ Option.value_map
          ~default:[]
          bedfile ~f:(fun f -> ["bedfile", `String f])
        @ Option.value_map ~default:[]
          igv_url_server_prefix
          ~f:(fun u -> ["Hosted at ~igv_url_server_prefix", `String u])
      in
      let json : Yojson.Basic.json =
        `Assoc [
          "report", `Assoc args;
        ]
      in
      json
end

module To_dot = struct
  (* type 'a repr = 'a Biokepi.EDSL.Compile.To_dot.repr *)

  open Biokepi_pipeline_edsl.To_dot

  let function_call name params =
    let a, arrows =
      List.partition_map params ~f:(fun (k, v) ->
          match v with
          | `String s -> `Fst (k, s)
          | _ -> `Snd (k, v)
        ) in
    Tree.node ~a name (List.map ~f:(fun (k,v) -> Tree.arrow k v) arrows)

  let string s = Tree.string s

  let report
      ?igv_url_server_prefix
      ~vcfs
      ~fastqcs
      ~normal_bam
      ~normal_bam_flagstat
      ~tumor_bam
      ~tumor_bam_flagstat
      ?optitype_normal
      ?optitype_tumor
      ?optitype_rna
      ?rna_bam
      ?vaxrank
      ?rna_bam_flagstat
      ?topiary
      ?isovar
      ?seq2hla
      ?stringtie
      ?bedfile
      ?kallisto
      ~metadata
      meta =
    fun ~var_count ->
      let module Rutils = Report_utils(struct let vc = var_count end) in
      let open Rutils in
      function_call "report" (
        ["run-name", string meta;]
        @ named_map vcfs
        @ named_map ~namefun:(fun n -> sprintf "%s-fastqc" n) fastqcs
        @ [
          "normal-bam", normal_bam ~var_count;
          "tumor-bam", tumor_bam ~var_count;
          "normal-bam-flagstat", normal_bam_flagstat ~var_count;
          "tumor-bam-flagstat", tumor_bam_flagstat ~var_count;
        ]
        @ opt "optitype-normal" optitype_normal
        @ opt "optitype-tumor" optitype_tumor
        @ opt "optitype-rna" optitype_rna
        @ opt "rna-bam" rna_bam
        @ opt "rna-bam-flagstat" rna_bam_flagstat
        @ opt "vaxrank" vaxrank
        @ opt "topiary" topiary
        @ opt "isovar" isovar
        @ opt "seq2hla" seq2hla
        @ opt "stringtie" stringtie
        @ opt_named_map kallisto
        @ Option.value_map
          ~default:[]
          bedfile ~f:(fun f -> ["bedfile", `String f])
      )
end

module Extend_file_spec = struct

  include Biokepi.EDSL.Compile.To_workflow.File_type_specification
  open Biokepi.KEDSL

  type t +=
      Final_report: single_file workflow_node -> t

  let () =
    add_to_string (function
      | Final_report _ -> Some "Final report"
      | other -> None);
    add_to_dependencies_edges_function (function
      | Final_report wf -> Some [depends_on wf]
      | _ -> None);
    ()

end

(** Testing mode forgets about the dependencies and creates a fresh
    HTML page everytime it's called: *)
let testing = ref false

module To_workflow
    (Config : sig
       include Biokepi.EDSL.Compile.To_workflow.Compiler_configuration
       val dot_content : string
     end)
= struct

  open Extend_file_spec
  open Biokepi.EDSL.Compile.To_workflow.Annotated_file

  let append_to ~file:fff str =
    let open Ketrew.EDSL in
    Program.shf "echo %s >> %s" (Filename.quote str) fff

  let relative_link ~href html =
    sprintf "<a href=%S>%s</a>"
      (canonicalize href) html

  type dirty_content = [ `String of string | `Cmd of string ] list

  let append_dirty_to ~file c =
    let open Ketrew.EDSL.Program in
    chain (List.map c ~f:(function
      | `String s -> append_to ~file s
      | `Cmd s -> shf "%s >> %s" s file
      ))

  let graphivz_rendered_links ~html_file dot_file =
    let open Ketrew.EDSL in
    let png = Filename.chop_extension dot_file ^ ".png" in
    let dotlog = Filename.chop_extension dot_file ^ ".dotlog" in
    let make_png =
      Program.(chain [
          shf "rm -f %s" dotlog;
          shf "(dot -v -x -Tpng  %s -o %s) || (echo DotFailed > %s)"
            dot_file png dotlog;
        ])
    in
    let piece_of_website : dirty_content = [
      `String {|<p>PNG: |};
      `Cmd (sprintf "(if [ -f %s ] ; then echo 'N/A' ; \
                     else echo %s ; fi)"
              dotlog
              (relative_link ~href:(Filename.basename png) "Here"
               |> Filename.quote));
      `String {|</p>|};
    ] in
    Program.(make_png && append_dirty_to piece_of_website ~file:html_file)

  let get_bam b = get_file b |> get_bam
  let get_vcf b = get_file b |> get_vcf
  let get_flagstat_result b = get_file b |> get_flagstat_result
  let get_cufflinks_result b = get_file b |> get_cufflinks_result
  let get_fastqc_result b = get_file b |> get_fastqc_result
  let get_optitype_result b = get_file b |> get_optitype_result
  let get_seq2hla_result b = get_file b |> get_seq2hla_result
  let get_vaxrank_result b = get_file b |> get_vaxrank_result
  let get_topiary_result b = get_file b |> get_topiary_result
  let get_isovar_result b = get_file b |> get_isovar_result
  let get_bed b = get_file b |> get_bed
  let get_kallisto_result b = get_file b |> get_kallisto_result
  let get_gtf b = get_file b |> get_gtf

  let report
      ?igv_url_server_prefix
      ~vcfs
      ~fastqcs
      ~normal_bam
      ~normal_bam_flagstat
      ~tumor_bam
      ~tumor_bam_flagstat
      ?optitype_normal
      ?optitype_tumor
      ?optitype_rna
      ?rna_bam
      ?vaxrank
      ?rna_bam_flagstat
      ?topiary
      ?isovar
      ?seq2hla
      ?stringtie
      ?bedfile
      ?kallisto
      ~metadata
      run_name =
    let open Ketrew.EDSL in
    let host = Biokepi.Machine.as_host Config.machine in
    let saving_base_path =
      Biokepi.EDSL.Compile.To_workflow.Saving_utilities.base_path
        ?results_dir:Config.results_dir ~work_dir:Config.work_dir
        ~name:"dummy" ()
      |> Filename.dirname
    in
    let relative_to_results path =
      let prefix_length = String.length saving_base_path in
      match String.sub path ~index:0 ~length:prefix_length with
      | Some p when p = saving_base_path ->
        let index =
          match path.[0] with
          | Some '/' -> prefix_length + 1
          | Some _ -> prefix_length
          | None -> ksprintf failwith "Path %S should not be empty?" path
        in
        String.sub_exn path ~index ~length:(String.length path - index)
      | Some _ | None ->
        ksprintf failwith "ERROR: %s is not a prefix of %s"
          saving_base_path path
    in
    let product =
      single_file ~host (saving_base_path // "index.html") in
    let igv_dot_xml =
      let opt_prefix p =
        let open Option in
        let prefix =
          igv_url_server_prefix
          >>= fun p ->
          match String.chop_suffix ~suffix:"/" p with
          | None -> return p
          | a -> a in
        match prefix with
        | None -> "./" ^ p
        | Some prefix -> Filename.concat prefix p
      in
      let bam_uri bam =
        relative_to_results (get_bam bam)#product#path |> opt_prefix in
      let normal_bam_path = bam_uri normal_bam in
      let tumor_bam_path = bam_uri tumor_bam in
      let rna_bam_path = Option.map rna_bam ~f:bam_uri in
      let vcf_uri vcf =
        relative_to_results (get_vcf vcf)#product#path |> opt_prefix in
      let vcfs =
        List.map vcfs ~f:(fun (name, vcf) ->
            Biokepi.Tools.Igvxml.vcf ~name ~path:(vcf_uri vcf)) in
      Biokepi.Tools.Igvxml.run ~run_with:Config.machine
        ~output_path:(saving_base_path // sprintf "local-igv-%s.xml" run_name)
        ~reference_genome:(get_bam normal_bam)#product#reference_build
        ~run_id:run_name
        ~normal_bam_path
        ~tumor_bam_path
        ?rna_bam_path
        ~vcfs
        ()
    in
    let edges =
      match !testing with
      | true -> [depends_on igv_dot_xml]
      | false ->
        let opt o f =
          Option.value_map o ~default:[] ~f:(fun v -> [ f v |> depends_on ])
        in
        let named_map get_func =
          List.map ~f:(fun (_, v) -> get_func v |> depends_on)
        in
        let mopt o f =
          let fnamed_map = named_map f in
          Option.value_map o ~default:[] ~f:fnamed_map
        in
        depends_on igv_dot_xml
        :: named_map get_vcf vcfs
        @ named_map get_fastqc_result fastqcs
        @ [
          get_bam normal_bam |> depends_on;
          get_bam tumor_bam |> depends_on;
          get_flagstat_result tumor_bam_flagstat |> depends_on;
          get_flagstat_result normal_bam_flagstat |> depends_on;
        ]
        @ opt optitype_normal get_optitype_result
        @ opt optitype_tumor get_optitype_result
        @ opt optitype_rna get_optitype_result
        @ opt rna_bam get_bam
        @ opt vaxrank get_vaxrank_result
        @ opt rna_bam_flagstat get_flagstat_result
        @ opt topiary get_topiary_result
        @ opt isovar get_isovar_result
        @ opt seq2hla get_seq2hla_result
        @ opt stringtie get_gtf
        @ mopt kallisto get_kallisto_result
    in
    let title = "Epidisco Report" in
    let header =
      sprintf
        {html|
          <!DOCTYPE html> <html lang="en">
          <head>
            <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootswatch/3.2.0/readable/bootstrap.min.css" type="text/css">
            <link rel="stylesheet" href="https://cdn.rawgit.com/hammerlab/ketrew/2d1c430cca52caa71e363a765ff8775a6ae14ba9/src/doc/code_style.css" type="text/css">
            <meta charset="utf-8">
            <title>%s</title></head><body><div class="container">
          |html}
        title
    in
    let footer = {html| </div></body></html> |html} in
    let saved_paths  ?(json_of_dirname = false) path =
      let thing = relative_to_results path in
      let json =
        String.take_while thing ~f:((<>) '/') ^ ".json" in
      (thing, json)
    in
    let list_item ?(with_json = false) ?(with_gzip = false) title path =
      let html, j = saved_paths path in
      let gzip_link =
        if with_gzip
        then Some (relative_link ~href:(html ^ ".gz") "GZipped")
        else None in
      let json_link =
        if with_json
        then Some (relative_link ~href:j "JSON-Provenance")
        else None in
      sprintf "<li>%s%s</li>"
        (relative_link ~href:html title)
        (if with_json || with_gzip then
           sprintf " (%s)"
             (List.filter_opt [json_link; gzip_link]
              |> String.concat ~sep:", ")
         else "")
    in
    let other_results_section =
      let potential_items =
        [
          "Normal-bam", Some ((get_bam normal_bam)#product#path);
          "Tumor-bam", Some ((get_bam tumor_bam)#product#path);
          "RNA-bam",
          Option.map rna_bam ~f:(fun b -> (get_bam b)#product#path);
        ]
        @ List.map vcfs ~f:(fun (name, repr) ->
            let wf = get_vcf repr in
            let title = sprintf "VCF: %s" name in
            title, Some wf#product#path)
        @ (Option.value_map ~default:[] kallisto ~f:(fun ks ->
            (List.map ks ~f:(fun (name, k) ->
                 let wf = get_kallisto_result k in
                 let title = sprintf "Kallisto: %s" name in
                 title, Some wf#product#path))))
        @ [
          "OptiType-Normal",
          Option.map optitype_normal ~f:(fun i ->
              (get_optitype_result i)#product#path);
          "OptiType-Tumor",
          Option.map optitype_tumor ~f:(fun i ->
              (get_optitype_result i)#product#path);
          "OptiType-RNA",
          Option.map optitype_rna ~f:(fun i ->
              (get_optitype_result i)#product#path);
          "Vaxrank ASCII",
          Option.(
            vaxrank >>= fun v ->
            (get_vaxrank_result v)#product#ascii_report_path);
          "Vaxrank PDF",
          Option.(
            vaxrank >>= fun v ->
            (get_vaxrank_result v)#product#pdf_report_path);
          "Vaxrank XLSX",
          Option.(
            vaxrank >>= fun v ->
            (get_vaxrank_result v)#product#xlsx_report_path);
          "Vaxrank Log (Debug)",
          Option.(
            vaxrank >>= fun v ->
            (Some (get_vaxrank_result v)#product#debug_log_path));
          "Topiary",
          Option.map topiary ~f:(fun i ->
              (get_topiary_result i)#product#path);
          "Isovar",
          Option.map isovar ~f:(fun i ->
              (get_isovar_result i)#product#path);
          "Seq2HLA-class1",
          Option.map seq2hla ~f:(fun i ->
              (get_seq2hla_result i)#product#class1_path);
          "Seq2HLA-class2",
          Option.map seq2hla ~f:(fun i ->
              (get_seq2hla_result i)#product#class2_path);
          "Seq2HLA-class1-expression",
          Option.map seq2hla ~f:(fun i ->
              (get_seq2hla_result i)#product#class1_expression_path);
          "Seq2HLA-class2-expression",
          Option.map seq2hla ~f:(fun i ->
              (get_seq2hla_result i)#product#class2_expression_path);
          "Stringtie",
          Option.map stringtie ~f:(fun i ->
              (get_gtf i)#product#path);
          "Bedfile",
          Option.map bedfile ~f:(fun f -> f);
        ]
      in
      sprintf "<h2>Results</h2><ul>%s</ul>"
        (List.filter_map potential_items ~f:(function
           | _, None -> None
           | title, Some p ->
             let with_gzip = Filename.check_suffix p ".vcf" in
             Some (list_item title p ~with_json:true ~with_gzip))
         |> String.concat ~sep:"")
    in
    let qc_section =
      let open Option in
      let items =
        List.concat_map fastqcs
          ~f:(fun (name, f) ->
              let f = get_fastqc_result f in
              List.mapi f#product#paths ~f:(fun i p ->
                  let title = sprintf "%s : Read %d" name i in
                  list_item title p))
      in
      let inline_code name cmd =
        let id = Digest.(string name |> to_hex) in
        let button = "&#x261F;" in
        [
          `String (sprintf {|<li>%s<a onclick="toggle_visibility('%s');">%s</a>
                             <div id="%s" style="display : none"><code><pre>|}
                     name id button id);
          `Cmd cmd;
          `String {|</pre></code></div></li>|};
        ]
      in
      let cat_flatstat f =
        sprintf "cat %s" (get_flagstat_result f)#product#path in
      [
        `String (
          sprintf {html|<h2>Dataset QC</h2><ul>
                        %s
                  |html}
            (String.concat ~sep:"\n" items));
      ]
      @ inline_code "Normal Bam Flagstat" (cat_flatstat normal_bam_flagstat)
      @ inline_code "Tumor Bam Flagstat" (cat_flatstat tumor_bam_flagstat)
      @ Option.value_map rna_bam_flagstat ~default:[]
        ~f:(fun f -> inline_code "RNA Bam Flagstat" (cat_flatstat f))
      @ [
        `String (sprintf
                   "<li>Experimental: %s (made with %s).</li>"
                   (relative_link
                      ~href:(Filename.basename igv_dot_xml#product#path)
                      "<code>IGV.xml</code>")
                   (Option.value_map igv_url_server_prefix
                      ~default:"relative paths"
                      ~f:(sprintf "URI <code>%s</code>"))
                );
        `String {|</ul>|}
      ]
    in
    let output str = append_to str ~file:product#path in
    let dot_file = saving_base_path // "pipeline.dot" in
    let make =
      Biokepi.Machine.quick_run_program
        Config.machine
        Program.(
          chain [
            shf "mkdir -p %s" (Filename.dirname product#path);
            shf "rm -f %s" product#path;
            output header;
            ksprintf output "<h1>%s</h1>" title;
            ksprintf output "<p>Run name: <code>%s</code></p>" run_name;
            ksprintf output "<p>Metadata:<ul>%s</ul></p>"
              (List.map metadata ~f:(fun (k, v) ->
                   sprintf "<li>%s: <code>%s</code></li>" k v)
               |> String.concat ~sep:"\n");
            ksprintf output
              "<p>Results path: <code>%s</code></p>\n" saving_base_path;
            append_dirty_to qc_section ~file:product#path;
            output other_results_section;
            shf "echo %s > %s" (Filename.quote Config.dot_content) dot_file;
            output "<hr/><h2>Pipeline Graph</h2>";
            graphivz_rendered_links ~html_file:product#path dot_file;
            output "<div id=\"svg-status\">SVG rendering in progress …</div>";
            output {html|
    <script src="https://mdaines.github.io/viz.js/bower_components/viz.js/viz.js"></script>
    <script>
function toggle_visibility(id) {
       var e = document.getElementById(id);
       if(e.style.display == 'block')
          e.style.display = 'none';
       else
          e.style.display = 'block';
    };
var xhttp = new XMLHttpRequest();
xhttp.onreadystatechange = function() {
    if (xhttp.readyState == 4 && xhttp.status == 200) {
        //document.body.innerHTML += "Inline:";
        document.getElementById("svg-status").innerHTML= "<i>Processing …</i>";
        var svg = Viz(xhttp.responseText, { format: "svg" });
        document.body.innerHTML += svg;
        // Set the font of all <text> elements:
        document.getElementById("svg-status").innerHTML= "<i>Post-processing …</i>";
        var l = document.getElementsByTagName("text")
        for (var i = 0; i < l.length; i++) { l[i].style.fontSize = 9; }
        document.getElementById("svg-status").innerHTML = "<b>Done:</b>";
     }
};
xhttp.open("GET", "./pipeline.dot", true);
xhttp.send();
                  </script>|html};
            output footer;
            shf "chmod -R a+rx %s" (Filename.dirname product#path);
            chain (
              let rec build acc dir =
                match Filename.dirname dir with
                | "/" -> List.rev acc
                | d ->
                  build (shf "chmod a+x %s || echo NoWorries" d :: acc) d
              in
              build [] product#path
            );
          ]
        ) in
    To_unit (
      Final_report (
        workflow_node product
          ~ensures:`Nothing
          ~name:(sprintf "%sReport %s" (if !testing then "Testing " else "") run_name)
          ~make
          ~edges
      )
    ) |> with_provenance "final-report" []

end
